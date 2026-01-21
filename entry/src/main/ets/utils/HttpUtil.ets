// utils/HttpUtil.ets
import http from '@ohos.net.http';

// ==================== 配置常量 ====================
// ⚠️ 修改为电脑的实际 IP 地址
const BASE_URL: string = 'http://192.168.1.130:8080';

// ==================== 接口定义 ====================
export interface UserInfo {
  userId: number;
  username: string;
  phone: string;
}

export interface LoginData {
  token: string;
  userInfo: UserInfo;
}

export interface LoginResponse {
  code: number;
  message: string;
  data: LoginData | null;
}

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
    console.info('[ConfigManager] Token已保存');
  }

  static getToken(): string {
    return ConfigManager.token;
  }

  static setUserInfo(userInfo: UserInfo): void {
    ConfigManager.userInfo = userInfo;
    console.info('[ConfigManager] 用户信息已保存:', JSON.stringify(userInfo));
  }

  static getUserInfo(): UserInfo | null {
    return ConfigManager.userInfo;
  }

  static clear(): void {
    ConfigManager.token = '';
    ConfigManager.userInfo = null;
    console.info('[ConfigManager] 登录信息已清除');
  }

  static isLoggedIn(): boolean {
    return ConfigManager.token !== '' && ConfigManager.userInfo !== null;
  }
}

// ==================== API服务 ====================
export class ApiService {

  static login(phone: string, password: string): Promise<LoginResponse> {
    return new Promise((resolve, reject) => {
      console.info('[ApiService] ========================================');
      console.info('[ApiService] 开始登录请求');
      console.info('[ApiService] BASE_URL:', BASE_URL);
      console.info('[ApiService] 完整地址:', BASE_URL + '/api/login');
      console.info('[ApiService] 手机号:', phone);
      console.info('[ApiService] ========================================');

      const httpRequest = http.createHttp();

      const requestData: LoginRequest = {
        phone: phone,
        password: password
      };

      const requestBody: string = JSON.stringify(requestData);
      console.info('[ApiService] 请求体:', requestBody);

      httpRequest.request(
        BASE_URL + '/api/login',
        {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'application/json',
            'Accept': 'application/json'
          },
          extraData: requestBody,
          connectTimeout: 30000,
          readTimeout: 30000
        }
      ).then((data: http.HttpResponse) => {
        console.info('[ApiService] ========== 请求成功 ==========');
        console.info('[ApiService] HTTP状态码:', data.responseCode);
        console.info('[ApiService] 响应头:', JSON.stringify(data.header));
        console.info('[ApiService] 响应体:', JSON.stringify(data.result));

        if (data.responseCode === 200) {
          try {
            let resultStr: string = '';
            if (typeof data.result === 'string') {
              resultStr = data.result;
            } else {
              resultStr = JSON.stringify(data.result);
            }

            const response: LoginResponse = JSON.parse(resultStr);
            console.info('[ApiService] 解析成功:', JSON.stringify(response));
            resolve(response);
          } catch (parseErr) {
            console.error('[ApiService] JSON解析失败:', JSON.stringify(parseErr));
            reject(new Error('响应数据解析失败'));
          }
        } else {
          console.error('[ApiService] HTTP状态码异常:', data.responseCode);
          reject(new Error('HTTP状态码: ' + data.responseCode));
        }

        httpRequest.destroy();

      }).catch((err: Error) => {
        // ✅ 打印详细错误信息
        console.error('[ApiService] ========== 请求失败 ==========');
        console.error('[ApiService] 错误类型:', typeof err);
        console.error('[ApiService] 错误信息:', JSON.stringify(err));
        console.error('[ApiService] 错误名称:', err.name);
        console.error('[ApiService] 错误消息:', err.message);
        console.error('[ApiService] ========================================');

        httpRequest.destroy();
        reject(err);
      });
    });
  }
}