# backend/app.py

from flask import Flask, request, jsonify, Response
from flask_sqlalchemy import SQLAlchemy
from flask_bcrypt import Bcrypt
from flask_jwt_extended import JWTManager, create_access_token, jwt_required, get_jwt_identity
from flask_cors import CORS
from datetime import timedelta
from urllib.parse import urlparse
from urllib.request import Request, urlopen
import os
from werkzeug.exceptions import BadRequest

app = Flask(__name__)

# 資料庫配置（優先使用環境變數，否則使用預設值）
import os
# 預設使用 ngrok 轉發的資料庫，如果需要使用本地資料庫，請在 .env 檔案中設定 DATABASE_URL
# ngrok 地址：0.tcp.jp.ngrok.io:14672 -> localhost:3306
database_url = os.environ.get('DATABASE_URL') or 'mysql+pymysql://123:456@0.tcp.jp.ngrok.io:14672/cookpal'
app.config['SQLALCHEMY_DATABASE_URI'] = database_url
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
# 資料庫連接池配置，防止連接中斷
app.config['SQLALCHEMY_ENGINE_OPTIONS'] = {
    'pool_recycle': 3600,  # 1小時後回收連接
    'pool_pre_ping': True,  # 使用前檢查連接是否有效
    'pool_size': 10,  # 連接池大小
    'max_overflow': 20,  # 最大溢出連接數
    'connect_args': {
        'connect_timeout': 10,  # 連接超時10秒
        'read_timeout': 30,  # 讀取超時30秒
        'write_timeout': 30,  # 寫入超時30秒
    }
}
app.config['JWT_SECRET_KEY'] = 'your-secret-key-change-in-production'
app.config['JWT_ACCESS_TOKEN_EXPIRES'] = timedelta(hours=24)

# 初始化擴展
db = SQLAlchemy(app)
bcrypt = Bcrypt(app)
jwt = JWTManager(app)

# 配置 CORS 以支援手機連接
CORS(app, resources={
    r"/api/*": {
        "origins": ["*"],  # 允許所有來源（開發環境）
        "methods": ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        "allow_headers": ["Content-Type", "Authorization"]
    }
})

# 用戶模型
class User(db.Model):
    __tablename__ = 'users'
    
    uid = db.Column(db.String(36), primary_key=True)
    account = db.Column(db.String(50), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    name = db.Column(db.String(100), nullable=True)
    created_at = db.Column(db.DateTime, default=db.func.current_timestamp())
    updated_at = db.Column(db.DateTime, default=db.func.current_timestamp(), onupdate=db.func.current_timestamp())

    def to_dict(self):
        return {
            'uid': self.uid,
            'account': self.account,
            'name': self.name,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }

class Recipe(db.Model):
    __tablename__ = 'recipes'

    uid = db.Column(db.String(36), primary_key=True)
    external_id = db.Column(db.String(50), unique=True, nullable=True)
    name = db.Column(db.String(255), nullable=True)
    ingredients = db.Column(db.Text, nullable=True)
    tag = db.Column(db.String(255), nullable=True)
    porsi = db.Column(db.String(50), nullable=True)
    cook_minutes = db.Column(db.Integer, nullable=True)
    instructions = db.Column(db.Text, nullable=True)
    image = db.Column(db.String(1024), nullable=True)
    likes = db.Column(db.Integer, nullable=True, default=0)
    created_at = db.Column(db.DateTime, nullable=True, default=db.func.current_timestamp())
    updated_at = db.Column(db.DateTime, nullable=True, default=db.func.current_timestamp(), onupdate=db.func.current_timestamp())

    def to_dict(self):
        return {
            'uid': self.uid or '',  # 主鍵不能為空
            'external_id': self.external_id or '',
            'name': self.name or '',
            'ingredients': self.ingredients or '',
            'tag': self.tag or '',
            'porsi': self.porsi or '',
            'cook_minutes': self.cook_minutes,  # 允許為 null
            'instructions': self.instructions or '',
            'image': self.image or '',
            'likes': self.likes or 0,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }

import uuid

class Favorite(db.Model):
    __tablename__ = 'favorites'
    
    uid = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = db.Column(db.String(36), db.ForeignKey('users.uid'), nullable=False)
    recipe_id = db.Column(db.String(36), db.ForeignKey('recipes.uid'), nullable=False)
    created_at = db.Column(db.DateTime, default=db.func.current_timestamp())
    
    # 建立關聯
    user = db.relationship('User', backref=db.backref('favorites', lazy=True))
    recipe = db.relationship('Recipe', backref=db.backref('favorited_by', lazy=True))
    
    def to_dict(self):
        return {
            'uid': self.uid,
            'user_id': self.user_id,
            'recipe_id': self.recipe_id,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            # 包含食譜資訊
            'recipe': self.recipe.to_dict() if self.recipe else None
        }


class History(db.Model):
    __tablename__ = 'history'
    
    uid = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = db.Column(db.String(36), db.ForeignKey('users.uid'), nullable=False)
    recipe_id = db.Column(db.String(36), db.ForeignKey('recipes.uid'), nullable=False)  # ← 改成 recipe_id (去掉 s)
    search_time = db.Column(db.DateTime, default=db.func.current_timestamp())
    
    user = db.relationship('User', backref=db.backref('history', lazy=True))
    recipe = db.relationship('Recipe', backref=db.backref('viewed_by', lazy=True))
    
    def to_dict(self):
        return {
            'uid': self.uid,
            'user_id': self.user_id,
            'recipe_id': self.recipe_id,  # ← 這裡也要改
            'search_time': self.search_time.isoformat() if self.search_time else None,
            'recipe': self.recipe.to_dict() if self.recipe else None
        }


# 中間表定義
recipe_ingredients = db.Table('recipe_ingredients',
    db.Column('recipe_id', db.String(36), db.ForeignKey('recipes.uid'), primary_key=True),
    db.Column('ingredient_id', db.String(36), db.ForeignKey('ingredients.id'), primary_key=True),
    db.Column('amount', db.String(50)),
    db.Column('created_at', db.DateTime, default=db.func.current_timestamp())
)

class Ingredient(db.Model):
    __tablename__ = 'ingredients'

    id = db.Column(db.String(36), primary_key=True)
    name = db.Column(db.String(255), nullable=False, unique=True)
    created_at = db.Column(db.DateTime, default=db.func.current_timestamp())

# 食譜按讚中間表
recipe_likes = db.Table('recipe_likes',
    db.Column('recipe_id', db.String(36), db.ForeignKey('recipes.uid'), primary_key=True),
    db.Column('user_id', db.String(36), db.ForeignKey('users.uid'), primary_key=True),
    db.Column('created_at', db.DateTime, default=db.func.current_timestamp())
)

# 錯誤處理
@app.errorhandler(400)
def bad_request(error):
    return jsonify({'error': '請求格式錯誤', 'message': str(error)}), 400

@app.errorhandler(401)
def unauthorized(error):
    return jsonify({'error': '未授權', 'message': '請先登入'}), 401

@app.errorhandler(404)
def not_found(error):
    return jsonify({'error': '找不到資源', 'message': str(error)}), 404

@app.errorhandler(500)
def internal_error(error):
    return jsonify({'error': '伺服器內部錯誤', 'message': str(error)}), 500

# 路由
@app.route('/api/health', methods=['GET'])
def health_check():
    """健康檢查端點"""
    return jsonify({
        'status': 'success',
        'message': 'API服務正常運行',
        'version': '1.0.0'
    })


@app.route('/api/image-proxy', methods=['GET'])
def image_proxy():
    '''Fetch remote images and return them with CORS headers for Flutter web.'''
    image_url = request.args.get('url')

    if not image_url:
        return jsonify({'error': 'missing_url', 'message': 'Image URL is required.'}), 400

    parsed = urlparse(image_url)
    if parsed.scheme not in ('http', 'https'):
        return jsonify({'error': 'invalid_scheme', 'message': 'Only http/https URLs are allowed.'}), 400

    try:
        upstream_request = Request(image_url, headers={'User-Agent': 'Mozilla/5.0'})
        with urlopen(upstream_request, timeout=10) as upstream_response:
            data = upstream_response.read()
            content_type = upstream_response.headers.get('Content-Type', 'application/octet-stream')

        response = Response(data, content_type=content_type)
        response.headers['Cache-Control'] = 'public, max-age=86400'
        response.headers['Access-Control-Allow-Origin'] = '*'
        return response
    except Exception as exc:
        return jsonify({
            'error': 'image_fetch_failed',
            'message': str(exc)
        }), 502


@app.route('/api/register', methods=['POST'])
def register():
    """用戶註冊"""
    try:
        data = request.get_json()
        
        # 除錯：顯示資料庫連接資訊
        print(f"🔍 資料庫 URI: {app.config['SQLALCHEMY_DATABASE_URI']}")
        
        # 除錯：檢查現有用戶數量
        user_count = User.query.count()
        print(f"📊 資料庫中現有用戶數量: {user_count}")
        
        # 除錯：列出所有現有用戶
        existing_users = User.query.all()
        print(f"👥 現有用戶列表:")
        for user in existing_users:
            print(f"  - ID: {user.uid}, 帳號: {user.account}, 姓名: {user.name}")
        
        # 驗證必要欄位
        if not data or not data.get('account') or not data.get('password'):
            return jsonify({
                'error': '缺少必要欄位',
                'message': '請提供帳號和密碼'
            }), 400
        
        # 檢查用戶是否已存在
        existing_account = User.query.filter_by(account=data['account']).first()
        if existing_account:
            print(f"❌ 帳號已存在: {data['account']}")
            return jsonify({
                'error': '帳號已存在',
                'message': '請選擇其他帳號'
            }), 400
        
        # 創建新用戶
        password_hash = bcrypt.generate_password_hash(data['password']).decode('utf-8')
        
        # 生成 UUID 作為 uid
        import uuid
        user_uid = str(uuid.uuid4())
        
        user = User(
            uid=user_uid,
            account=data['account'],
            password_hash=password_hash,
            name=data.get('name') or '未設定'
        )
        
        db.session.add(user)
        db.session.commit()
        
        return jsonify({
            'status': 'success',
            'message': '註冊成功',
            'user': user.to_dict()
        }), 201
        
    except Exception as e:
        db.session.rollback()
        return jsonify({
            'error': '註冊失敗',
            'message': str(e)
        }), 500

@app.route('/api/login', methods=['POST'])
def login():
    """用戶登入"""
    try:
        data = request.get_json()
        
        if not data or not data.get('account') or not data.get('password'):
            return jsonify({
                'error': '缺少必要欄位',
                'message': '請提供帳號和密碼'
            }), 400
        
        # 查找用戶
        user = User.query.filter_by(account=data['account']).first()
        
        # 檢查密碼（支援兩種格式：bcrypt 和 sha256）
        password_valid = False
        if user:
            try:
                # 先嘗試 bcrypt 驗證
                password_valid = bcrypt.check_password_hash(user.password_hash, data['password'])
            except:
                # 如果 bcrypt 失敗，嘗試 sha256 驗證
                import hashlib
                password_valid = user.password_hash == hashlib.sha256(data['password'].encode()).hexdigest()
        
        if not user or not password_valid:
            return jsonify({
                'error': '登入失敗',
                'message': '帳號或密碼錯誤'
            }), 401
        
        # 生成JWT token
        access_token = create_access_token(identity=user.uid)
        
        return jsonify({
            'status': 'success',
            'message': '登入成功',
            'access_token': access_token,
            'user': user.to_dict()
        }), 200
        
    except Exception as e:
        return jsonify({
            'error': '登入失敗',
            'message': str(e)
        }), 500

@app.route('/api/profile', methods=['GET'])
@jwt_required()
def get_profile():
    """獲取用戶資料"""
    try:
        uid = get_jwt_identity()
        user = User.query.get(uid)
        
        if not user:
            return jsonify({
                'error': '用戶不存在',
                'message': '找不到指定的用戶'
            }), 404
        
        return jsonify({
            'status': 'success',
            'user': user.to_dict()
        }), 200
        
    except Exception as e:
        return jsonify({
            'error': '獲取資料失敗',
            'message': str(e)
        }), 500

@app.route('/api/profile', methods=['PUT'])
@jwt_required()
def update_profile():
    """更新用戶資料"""
    try:
        uid = get_jwt_identity()
        user = User.query.get(uid)
        
        if not user:
            return jsonify({
                'error': '用戶不存在',
                'message': '找不到指定的用戶'
            }), 404
        
        data = request.get_json()
        
        # 更新允許的欄位
        if 'name' in data:
            user.name = data['name']
        
        if 'account' in data:
            # 檢查帳號是否已被其他用戶使用
            existing_user = User.query.filter(
                User.account == data['account'],
                User.uid != uid
            ).first()
            if existing_user:
                return jsonify({
                    'error': '帳號已存在',
                    'message': '請使用其他帳號'
                }), 400
            user.account = data['account']
        
        db.session.commit()
        
        return jsonify({
            'status': 'success',
            'message': '資料更新成功',
            'user': user.to_dict()
        }), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({
            'error': '更新失敗',
            'message': str(e)
        }), 500

@app.route('/api/logout', methods=['POST'])
@jwt_required()
def logout():
    """用戶登出（客戶端需要刪除token）"""
    return jsonify({
        'status': 'success',
        'message': '登出成功'
    }), 200

@app.route('/api/recipes', methods=['GET'])
@jwt_required()
def get_recipes():
    """獲取食譜列表"""
    max_retries = 3
    retry_count = 0
    
    while retry_count < max_retries:
        try:
            page = request.args.get('page', 1, type=int)
            per_page = request.args.get('per_page', 10, type=int)

            # 使用更安全的查詢方式，避免 count() 導致長時間查詢
            query = Recipe.query.order_by(Recipe.created_at.desc())
            
            # 先獲取第一頁數據來檢查是否有食譜
            first_page = query.limit(1).all()
            
            # 如果沒有食譜，創建一個示例食譜
            if not first_page:
                try:
                    import uuid
                    recipe = Recipe(
                        uid=str(uuid.uuid4()),
                        external_id='000001',
                        name='示例食譜：寶寶麥精銀耳湯',
                        ingredients='銀耳 30g,水 500ml',
                        tag='湯品',
                        porsi='2人份',
                        cook_minutes=30,
                        instructions='1. 將銀耳泡發,2. 加入水煮沸,3. 悶煮30分鐘即可',
                        image='https://tokyo-kitchen.icook.network/uploads/recipe/cover/479956/a296741a0c90c862.jpg',
                        likes=0
                    )
                    db.session.add(recipe)
                    db.session.commit()
                except Exception as commit_error:
                    db.session.rollback()
                    print(f"創建示例食譜失敗: {commit_error}")
            
            # 重新獲取查詢
            query = Recipe.query.order_by(Recipe.created_at.desc())

            # 使用分頁，但先獲取總數（使用更安全的方式）
            try:
                # 先獲取總數（使用更快的查詢）
                total = db.session.query(db.func.count(Recipe.uid)).scalar() or 0
                
                # 計算分頁
                offset = (page - 1) * per_page
                recipes = query.offset(offset).limit(per_page).all()
                
                pages = (total + per_page - 1) // per_page if total > 0 else 1
                
            except Exception as pagination_error:
                # 如果分頁失敗，嘗試使用舊方法
                try:
                    pagination = query.paginate(
                        page=page,
                        per_page=per_page,
                        error_out=False
                    )
                    recipes = pagination.items
                    total = pagination.total
                    pages = pagination.pages
                except TypeError:
                    # 舊版 SQLAlchemy 的寫法
                    pagination = query.paginate(
                        page,
                        per_page,
                        False
                    )
                    recipes = pagination.items
                    total = pagination.total
                    pages = pagination.pages

            return jsonify({
                'status': 'success',
                'recipes': [recipe.to_dict() for recipe in recipes],
                'total': total,
                'pages': pages,
                'current_page': page,
            }), 200

        except Exception as e:
            retry_count += 1
            import traceback
            error_msg = str(e)
            print(f"錯誤（嘗試 {retry_count}/{max_retries}）：{error_msg}")
            print(f"詳細錯誤：{traceback.format_exc()}")
            
            # 如果是連接錯誤，嘗試重新連接
            if 'Lost connection' in error_msg or 'OperationalError' in error_msg:
                try:
                    db.session.rollback()
                    db.session.close()
                    # 重新初始化連接
                    db.session.execute(db.text('SELECT 1'))
                except:
                    pass
                
                if retry_count < max_retries:
                    import time
                    time.sleep(1)  # 等待1秒後重試
                    continue
            
            # 如果重試次數用完或不是連接錯誤，返回錯誤
            return jsonify({
                'error': '獲取食譜列表失敗',
                'message': error_msg,
                'retry_count': retry_count
            }), 500
    
    # 所有重試都失敗
    return jsonify({
        'error': '獲取食譜列表失敗',
        'message': '資料庫連接失敗，請稍後再試'
    }), 500


# ==================== 搜尋功能 API ====================
# 請將以下代碼添加到 app.py 中 get_recipes() 函數之後

@app.route('/api/recipes/search', methods=['GET'])
@jwt_required()
def search_recipes():
    """搜尋食譜（支援文字搜尋和標籤篩選）"""
    try:
        # 取得搜尋參數
        search_text = request.args.get('q', '').strip()  # 搜尋關鍵字
        tags = request.args.getlist('tags')  # 標籤列表（可多選）
        page = request.args.get('page', 1, type=int)
        per_page = request.args.get('per_page', 20, type=int)
        
        # 建立基礎查詢
        query = Recipe.query
        
        # 文字搜尋：搜尋 name, ingredients, tag 欄位
        if search_text:
            search_pattern = f'%{search_text}%'
            query = query.filter(
                db.or_(
                    Recipe.name.like(search_pattern),
                    Recipe.ingredients.like(search_pattern),
                    Recipe.tag.like(search_pattern)
                )
            )
        
        # 標籤篩選：搜尋 tag 欄位（支援多標籤）
        if tags:
            tag_conditions = []
            for tag in tags:
                tag_conditions.append(Recipe.tag.like(f'%{tag}%'))
            query = query.filter(db.or_(*tag_conditions))
        
        # 排序：最新的在前
        query = query.order_by(Recipe.created_at.desc())
        
        # 分頁
        try:
            pagination = query.paginate(
                page=page,
                per_page=per_page,
                error_out=False
            )
        except TypeError:
            pagination = query.paginate(page, per_page, False)
        
        return jsonify({
            'status': 'success',
            'recipes': [recipe.to_dict() for recipe in pagination.items],
            'total': pagination.total,
            'pages': pagination.pages,
            'current_page': page,
        }), 200
        
    except Exception as e:
        import traceback
        print(f'搜尋錯誤：{str(e)}')
        print(f'詳細錯誤：{traceback.format_exc()}')
        return jsonify({
            'error': '搜尋失敗',
            'message': str(e)
        }), 500


@app.route('/api/categories', methods=['GET'])
@jwt_required()
def get_categories():
    """取得所有分類"""
    try:
        categories = db.session.execute(
            db.text('SELECT * FROM categories ORDER BY id')
        ).fetchall()
        
        categories_list = []
        for cat in categories:
            categories_list.append({
                'id': cat[0],
                'category_name': cat[1]
            })
        
        return jsonify({
            'status': 'success',
            'categories': categories_list
        }), 200
        
    except Exception as e:
        return jsonify({
            'error': '取得分類失敗',
            'message': str(e)
        }), 500


@app.route('/api/keywords', methods=['GET'])
@jwt_required()
def get_keywords():
    """取得關鍵字（可依分類篩選）"""
    try:
        category_id = request.args.get('category_id', type=int)
        
        if category_id:
            keywords = db.session.execute(
                db.text('SELECT * FROM keywords WHERE category_id = :cat_id ORDER BY id'),
                {'cat_id': category_id}
            ).fetchall()
        else:
            keywords = db.session.execute(
                db.text('SELECT * FROM keywords ORDER BY category_id, id')
            ).fetchall()
        
        keywords_list = []
        for kw in keywords:
            keywords_list.append({
                'id': kw[0],
                'category_id': kw[1],
                'keyword_name': kw[2]
            })
        
        return jsonify({
            'status': 'success',
            'keywords': keywords_list
        }), 200
        
    except Exception as e:
        return jsonify({
            'error': '取得關鍵字失敗',
            'message': str(e)
        }), 500

# ==================== 我的最愛 API ====================

@app.route('/api/favorites', methods=['POST'])
@jwt_required()
def add_favorite():
    """新增到我的最愛"""
    try:
        uid = get_jwt_identity()
        data = request.get_json()
        
        if not data or not data.get('recipe_id'):
            return jsonify({
                'error': '缺少必要欄位',
                'message': '請提供食譜 ID'
            }), 400
        
        recipe_id = data['recipe_id']
        
        # 檢查食譜是否存在
        recipe = Recipe.query.get(recipe_id)
        if not recipe:
            return jsonify({
                'error': '食譜不存在',
                'message': '找不到指定的食譜'
            }), 404
        
        # 檢查是否已經在最愛中
        existing_favorite = Favorite.query.filter_by(
            user_id=uid,
            recipe_id=recipe_id
        ).first()
        
        if existing_favorite:
            return jsonify({
                'error': '已在最愛中',
                'message': '此食譜已在您的最愛清單中'
            }), 400
        
        # 新增到最愛
        favorite = Favorite(
            user_id=uid,
            recipe_id=recipe_id
        )
        
        db.session.add(favorite)
        db.session.commit()
        
        return jsonify({
            'status': 'success',
            'message': '成功加入最愛',
            'favorite': favorite.to_dict()
        }), 201
        
    except Exception as e:
        db.session.rollback()
        return jsonify({
            'error': '新增最愛失敗',
            'message': str(e)
        }), 500


@app.route('/api/favorites/<string:recipe_id>', methods=['DELETE'])
@jwt_required()
def remove_favorite(recipe_id):
    """從我的最愛移除"""
    try:
        uid = get_jwt_identity()
        
        # 查找最愛項目
        favorite = Favorite.query.filter_by(
            user_id=uid,
            recipe_id=recipe_id
        ).first()
        
        if not favorite:
            return jsonify({
                'error': '找不到最愛項目',
                'message': '此食譜不在您的最愛清單中'
            }), 404
        
        # 刪除最愛
        db.session.delete(favorite)
        db.session.commit()
        
        return jsonify({
            'status': 'success',
            'message': '成功移除最愛'
        }), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({
            'error': '移除最愛失敗',
            'message': str(e)
        }), 500


@app.route('/api/favorites', methods=['GET'])
@jwt_required()
def get_favorites():
    """取得我的最愛清單"""
    try:
        uid = get_jwt_identity()
        
        # 取得使用者的所有最愛
        favorites = Favorite.query.filter_by(user_id=uid)\
            .order_by(Favorite.created_at.desc())\
            .all()
        
        # 格式化結果,包含食譜完整資訊
        favorites_list = []
        for fav in favorites:
            if fav.recipe:  # 確保食譜存在
                recipe_data = fav.recipe.to_dict()
                # 確保包含 image 欄位
                favorites_list.append({
                    'uid': recipe_data.get('uid'),
                    'name': recipe_data.get('name'),
                    'image': recipe_data.get('image'),
                    'tag': recipe_data.get('tag'),
                    'cook_minutes': recipe_data.get('cook_minutes'),
                    'ingredients': recipe_data.get('ingredients'),
                    'instructions': recipe_data.get('instructions'),
                    'porsi': recipe_data.get('porsi'),
                    'likes': recipe_data.get('likes'),
                    'favorite_uid': fav.uid,
                    'favorited_at': fav.created_at.isoformat() if fav.created_at else None
                })
        
        return jsonify({
            'status': 'success',
            'favorites': favorites_list,
            'total': len(favorites_list)
        }), 200
        
    except Exception as e:
        return jsonify({
            'error': '取得最愛清單失敗',
            'message': str(e)
        }), 500


@app.route('/api/favorites/check/<string:recipe_id>', methods=['GET'])
@jwt_required()
def check_favorite(recipe_id):
    """檢查食譜是否在最愛中"""
    try:
        uid = get_jwt_identity()
        
        favorite = Favorite.query.filter_by(
            user_id=uid,
            recipe_id=recipe_id
        ).first()
        
        return jsonify({
            'status': 'success',
            'is_favorite': favorite is not None
        }), 200
        
    except Exception as e:
        return jsonify({
            'error': '檢查最愛狀態失敗',
            'message': str(e)
        }), 500


# ==================== 歷史紀錄 API ====================

@app.route('/api/history', methods=['POST'])
@jwt_required()
def add_history():
    """新增歷史紀錄"""
    try:
        uid = get_jwt_identity()
        data = request.get_json()
        
        if not data or not data.get('recipe_id'):
            return jsonify({
                'error': '缺少必要欄位',
                'message': '請提供食譜 ID'
            }), 400
        
        recipe_id = data['recipe_id']
        
        # 檢查食譜是否存在
        recipe = Recipe.query.get(recipe_id)
        if not recipe:
            return jsonify({
                'error': '食譜不存在',
                'message': '找不到指定的食譜'
            }), 404
        
        # 檢查今天是否已有相同的歷史紀錄
        from datetime import datetime, date
        today = date.today()
        existing_history = History.query.filter(
            History.user_id == uid,
            History.recipe_id == recipe_id,  # ← 修正這裡
            db.func.date(History.search_time) == today
        ).first()
        
        if existing_history:
            # 更新時間
            existing_history.search_time = datetime.now()
            db.session.commit()
            
            return jsonify({
                'status': 'success',
                'message': '已更新瀏覽時間',
                'history': existing_history.to_dict()
            }), 200
        else:
            # 新增歷史紀錄
            history = History(
                user_id=uid,
                recipe_id=recipe_id  # ← 修正這裡
            )
            
            db.session.add(history)
            db.session.commit()
            
            return jsonify({
                'status': 'success',
                'message': '成功記錄歷史',
                'history': history.to_dict()
            }), 201
        
    except Exception as e:
        db.session.rollback()
        import traceback
        print(f"新增歷史紀錄錯誤: {str(e)}")
        print(traceback.format_exc())
        return jsonify({
            'error': '新增歷史紀錄失敗',
            'message': str(e)
        }), 500


@app.route('/api/history', methods=['GET'])
@jwt_required()
def get_history():
    """取得歷史紀錄"""
    try:
        uid = get_jwt_identity()
        
        # 取得查詢參數
        limit = request.args.get('limit', 50, type=int)
        
        # 取得使用者的歷史紀錄
        history_items = History.query.filter_by(user_id=uid)\
            .order_by(History.search_time.desc())\
            .limit(limit)\
            .all()
        
        # 格式化結果,包含食譜完整資訊
        history_list = []
        for item in history_items:
            if item.recipe:  # 確保食譜存在
                recipe_data = item.recipe.to_dict()
                # 添加歷史的 uid 和 search_time
                recipe_data['history_uid'] = item.uid
                recipe_data['search_time'] = item.search_time.isoformat() if item.search_time else None
                history_list.append(recipe_data)
        
        return jsonify({
            'status': 'success',
            'history': history_list,
            'total': len(history_list)
        }), 200
        
    except Exception as e:
        return jsonify({
            'error': '取得歷史紀錄失敗',
            'message': str(e)
        }), 500


@app.route('/api/history/<int:history_id>', methods=['DELETE'])
@jwt_required()
def delete_history_item(history_id):
    """刪除單筆歷史紀錄"""
    try:
        uid = get_jwt_identity()
        
        # 查找歷史紀錄(確保是該使用者的紀錄)
        history_item = History.query.filter_by(
            uid=history_id,
            user_id=uid
        ).first()
        
        if not history_item:
            return jsonify({
                'error': '找不到歷史紀錄',
                'message': '此歷史紀錄不存在或不屬於您'
            }), 404
        
        # 刪除歷史紀錄
        db.session.delete(history_item)
        db.session.commit()
        
        return jsonify({
            'status': 'success',
            'message': '成功刪除歷史紀錄'
        }), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({
            'error': '刪除歷史紀錄失敗',
            'message': str(e)
        }), 500


@app.route('/api/history/clear', methods=['DELETE'])
@jwt_required()
def clear_history():
    """清空所有歷史紀錄"""
    try:
        uid = get_jwt_identity()
        
        # 刪除該使用者的所有歷史紀錄
        deleted_count = History.query.filter_by(user_id=uid).delete()
        
        db.session.commit()
        
        return jsonify({
            'status': 'success',
            'message': '成功清空歷史紀錄',
            'deleted_count': deleted_count
        }), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({
            'error': '清空歷史紀錄失敗',
            'message': str(e)
        }), 500

        

@app.route('/api/recipes/<string:recipe_id>', methods=['GET'])
@jwt_required()
def get_recipe(recipe_id):
    """獲取食譜詳情"""
    try:
        recipe = Recipe.query.get(recipe_id)
        if not recipe:
            return jsonify({
                'error': '食譜不存在',
                'message': '找不到指定的食譜'
            }), 404

        return jsonify({
            'status': 'success',
            'recipe': recipe.to_dict()
        }), 200

    except Exception as e:
        return jsonify({
            'error': '獲取食譜詳情失敗',
            'message': str(e)
        }), 500

@app.route('/api/recipes/<string:recipe_id>/like', methods=['POST'])
@jwt_required()
def like_recipe(recipe_id):
    """喜歡/取消喜歡食譜"""
    try:
        uid = get_jwt_identity()
        recipe = Recipe.query.get(recipe_id)
        
        if not recipe:
            return jsonify({
                'error': '食譜不存在',
                'message': '找不到指定的食譜'
            }), 404
            
        user = User.query.get(uid)
        if user in recipe.likes:
            recipe.likes.remove(user)
            message = '已取消喜歡'
        else:
            recipe.likes.append(user)
            message = '已添加到喜歡'
            
        db.session.commit()
        
        return jsonify({
            'status': 'success',
            'message': message,
            'likes': recipe.likes.count()
        }), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({
            'error': '操作失敗',
            'message': str(e)
        }), 500

if __name__ == '__main__':
    with app.app_context():
        db.create_all()
    app.run(debug=True, host='0.0.0.0', port=5000)