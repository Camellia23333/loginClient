import http from '@ohos.net.http';

// 配置 API 基础地址
const BASE_URL = 'http://192.168.1.130:3000/api';

// API 响应接口
export class ApiResponse<T> {
  code: number = 0;
  message: string = '';
  data: T | null = null;
}

// 用户登录/注册响应数据
export class UserResponseData {
  token: string = '';
  userInfo: UserInfoData = new UserInfoData();
}

export class UserInfoData {
  id: number = 0;
  account: string = '';
  nickname: string = '';
  avatar: string = '';
}


// HTTP 工具类
export class HttpUtil {
  /**
   * 通用 HTTP 请求方法
   */
  static async request<T>(
    url: string,
    method: http.RequestMethod,
    data: Record<string, string | number> | null,
    headers: Record<string, string> | null
  ): Promise<ApiResponse<T>> {
    const httpRequest = http.createHttp();

    try {
      const fullUrl = BASE_URL + url;
      const token = AppStorage.get<string>('token') || '';

      const defaultHeaders: Record<string, string> = {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`
      };

      // 合并 headers
      let finalHeaders = defaultHeaders;
      if (headers) {
        const keys = Object.keys(headers);
        for (let i = 0; i < keys.length; i++) {
          const key = keys[i];
          finalHeaders[key] = headers[key];
        }
      }

      const options: http.HttpRequestOptions = {
        method: method,
        header: finalHeaders,
        readTimeout: 30000,
        connectTimeout: 30000
      };

      // 处理请求数据
      if (data) {
        if (method === http.RequestMethod.GET) {
          const params: string[] = [];
          const keys = Object.keys(data);
          for (let i = 0; i < keys.length; i++) {
            const key = keys[i];
            const value = data[key];
            params.push(`${key}=${encodeURIComponent(String(value))}`);
          }
          options.extraData = fullUrl + '?' + params.join('&');
        } else {
          options.extraData = JSON.stringify(data);
        }
      }

      const response = await httpRequest.request(fullUrl, options);

      if (response.responseCode === 200) {
        const result = JSON.parse(response.result as string) as ApiResponse<T>;
        return result;
      } else {
        const errorResponse = new ApiResponse<T>();
        errorResponse.code = -1;
        errorResponse.message = `请求失败: ${response.responseCode}`;
        return errorResponse;
      }
    } catch (error) {
      console.error('HTTP 请求错误:', JSON.stringify(error));
      const errorResponse = new ApiResponse<T>();
      errorResponse.code = -1;
      errorResponse.message = '网络请求失败';
      return errorResponse;
    } finally {
      httpRequest.destroy();
    }
  }

  static get<T>(url: string, params: Record<string, string | number> | null): Promise<ApiResponse<T>> {
    return HttpUtil.request<T>(url, http.RequestMethod.GET, params, null);
  }

  static post<T>(url: string, data: Record<string, string | number> | null): Promise<ApiResponse<T>> {
    return HttpUtil.request<T>(url, http.RequestMethod.POST, data, null);
  }

  static put<T>(url: string, data: Record<string, string | number> | null): Promise<ApiResponse<T>> {
    return HttpUtil.request<T>(url, http.RequestMethod.PUT, data, null);
  }

  static deleteRequest<T>(url: string, params: Record<string, string | number> | null): Promise<ApiResponse<T>> {
    return HttpUtil.request<T>(url, http.RequestMethod.DELETE, params, null);
  }
}

// ========== API 接口定义 ==========

export class ApiService {
  // ===== 用户相关 =====
  static async login(account: string, password: string): Promise<ApiResponse<UserResponseData>> {
    const data: Record<string, string> = {
      'account': account,
      'password': password
    };
    return await HttpUtil.post<UserResponseData>('/user/login', data);
  }

}


// ========== 配置管理 ==========
export class ConfigManager {
  // 设置 API 基地址
  static setBaseUrl(url: string): void {
    AppStorage.setOrCreate('apiBaseUrl', url);
  }

  static getBaseUrl(): string {
    return AppStorage.get<string>('apiBaseUrl') || BASE_URL;
  }

  // 设置用户 Token
  static setToken(token: string): void {
    AppStorage.setOrCreate('token', token);
  }

  static getToken(): string {
    return AppStorage.get<string>('token') || '';
  }

  static clearToken(): void {
    AppStorage.setOrCreate('token', '');
  }

  // 设置用户信息
  static setUserInfo(userInfo: UserInfoData): void {
    AppStorage.setOrCreate('userInfo', JSON.stringify(userInfo));
  }

  static getUserInfo(): UserInfoData {
    const userInfoStr = AppStorage.get<string>('userInfo') || '{}';
    return JSON.parse(userInfoStr) as UserInfoData;
  }

  static clearUserInfo(): void {
    AppStorage.setOrCreate('userInfo', '{}');
  }
}