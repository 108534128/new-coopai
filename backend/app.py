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

# 資料庫配置
app.config['SQLALCHEMY_DATABASE_URI'] = 'mysql+pymysql://root:123456@127.0.0.1/cookpal'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['JWT_SECRET_KEY'] = 'your-secret-key-change-in-production'
app.config['JWT_ACCESS_TOKEN_EXPIRES'] = timedelta(hours=24)

# 初始化擴展
db = SQLAlchemy(app)
bcrypt = Bcrypt(app)
jwt = JWTManager(app)
CORS(app)  # 啟用 CORS 支援

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

if __name__ == '__main__':
    with app.app_context():
        db.create_all()
    app.run(debug=True, host='0.0.0.0', port=5000)
