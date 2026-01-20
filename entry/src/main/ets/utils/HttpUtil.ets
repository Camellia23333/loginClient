// utils/HttpUtil.ets
import http from '@ohos.net.http';

// ==================== 配置常量 ====================
// 服务器地址,修改为实际IP地址
const BASE_URL: string = 'http://192.168.1.100:8080';

// ==================== 接口定义 ====================

// 用户信息接口
export interface UserInfo {
  userId: number;
  username: string;
  phone: string;
}

// 登录响应数据接口
export interface LoginData {
  token: string;
  userInfo: UserInfo;
}

// 统一响应接口
export interface LoginResponse {
  code: number;
  message: string;
  data: LoginData | null;
}

// 登录请求参数接口
interface LoginRequest {
  phone: string;
  password: string;
}

// ==================== 配置管理器 ====================
export class ConfigManager {
  private static token: string = '';
  private static userInfo: UserInfo | null = null;

  static setToken(token: string): void {
    ConfigManager.token = token;
    console.log('Token已保存');
  }

  static getToken(): string {
    return ConfigManager.token;
  }

  static setUserInfo(userInfo: UserInfo): void {
    ConfigManager.userInfo = userInfo;
    console.log('用户信息已保存:', JSON.stringify(userInfo));
  }

  static getUserInfo(): UserInfo | null {
    return ConfigManager.userInfo;
  }

  static clear(): void {
    ConfigManager.token = '';
    ConfigManager.userInfo = null;
    console.log('登录信息已清除');
  }

  static isLoggedIn(): boolean {
    return ConfigManager.token !== '' && ConfigManager.userInfo !== null;
  }
}

// ==================== API服务 ====================
export class ApiService {

  /**
   * 登录接口
   */
  static login(phone: string, password: string): Promise<LoginResponse> {
    return new Promise((resolve, reject) => {
      const httpRequest = http.createHttp();

      const requestData: LoginRequest = {
        phone: phone,
        password: password
      };

      console.log('发起登录请求:', BASE_URL + '/api/login');
      console.log('请求参数:', JSON.stringify(requestData));

      httpRequest.request(
        BASE_URL + '/api/login',
        {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'application/json'
          },
          extraData: JSON.stringify(requestData),
          connectTimeout: 15000,
          readTimeout: 15000
        },
        (err, data) => {
          if (!err) {
            console.log('请求成功，状态码:', data.responseCode);
            console.log('响应数据:', data.result);

            try {
              const response: LoginResponse = JSON.parse(data.result as string);
              resolve(response);
            } catch (parseError) {
              console.error('JSON解析失败:', parseError);
              reject(new Error('响应数据解析失败'));
            }
          } else {
            console.error('请求失败:', JSON.stringify(err));
            reject(err);
          }

          httpRequest.destroy();
        }
      );
    });
  }
}