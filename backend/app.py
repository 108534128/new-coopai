from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy
from flask_bcrypt import Bcrypt
from flask_jwt_extended import JWTManager, create_access_token, jwt_required, get_jwt_identity
from flask_cors import CORS
from datetime import timedelta
import os
from werkzeug.exceptions import BadRequest

app = Flask(__name__)

# 資料庫配置
app.config['SQLALCHEMY_DATABASE_URI'] = 'mysql+pymysql://root:123456@127.0.0.1/food_recommendation_system'
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
    
    user_id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(50), unique=True, nullable=False)
    email = db.Column(db.String(100), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    full_name = db.Column(db.String(100))
    created_at = db.Column(db.DateTime, default=db.func.current_timestamp())
    updated_at = db.Column(db.DateTime, default=db.func.current_timestamp(), onupdate=db.func.current_timestamp())
    
    def to_dict(self):
        return {
            'user_id': self.user_id,
            'username': self.username,
            'email': self.email,
            'full_name': self.full_name,
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
        
        # 驗證必要欄位
        if not data or not data.get('username') or not data.get('email') or not data.get('password'):
            return jsonify({
                'error': '缺少必要欄位',
                'message': '請提供用戶名、電子郵件和密碼'
            }), 400
        
        # 檢查用戶是否已存在
        if User.query.filter_by(username=data['username']).first():
            return jsonify({
                'error': '用戶名已存在',
                'message': '請選擇其他用戶名'
            }), 400
            
        if User.query.filter_by(email=data['email']).first():
            return jsonify({
                'error': '電子郵件已存在',
                'message': '請使用其他電子郵件'
            }), 400
        
        # 創建新用戶
        password_hash = bcrypt.generate_password_hash(data['password']).decode('utf-8')
        user = User(
            username=data['username'],
            email=data['email'],
            password_hash=password_hash,
            full_name=data.get('full_name', '')
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
        
        if not data or not data.get('username') or not data.get('password'):
            return jsonify({
                'error': '缺少必要欄位',
                'message': '請提供用戶名和密碼'
            }), 400
        
        # 查找用戶（支援用戶名或電子郵件登入）
        user = User.query.filter(
            (User.username == data['username']) | (User.email == data['username'])
        ).first()
        
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
                'message': '用戶名或密碼錯誤'
            }), 401
        
        # 生成JWT token
        access_token = create_access_token(identity=user.user_id)
        
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
        user_id = get_jwt_identity()
        user = User.query.get(user_id)
        
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
        user_id = get_jwt_identity()
        user = User.query.get(user_id)
        
        if not user:
            return jsonify({
                'error': '用戶不存在',
                'message': '找不到指定的用戶'
            }), 404
        
        data = request.get_json()
        
        # 更新允許的欄位
        if 'full_name' in data:
            user.full_name = data['full_name']
        
        if 'email' in data:
            # 檢查電子郵件是否已被其他用戶使用
            existing_user = User.query.filter(
                User.email == data['email'],
                User.user_id != user_id
            ).first()
            if existing_user:
                return jsonify({
                    'error': '電子郵件已存在',
                    'message': '請使用其他電子郵件'
                }), 400
            user.email = data['email']
        
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