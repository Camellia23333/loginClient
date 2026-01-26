// utils/HttpUtil.ets
import http from '@ohos.net.http';
import { promptAction, router } from '@kit.ArkUI';
import type { UIContext } from '@ohos.arkui.UIContext';
import { BusinessError } from '@kit.BasicServicesKit';
import preferences from '@ohos.data.preferences';

// ==================== 配置常量 ====================
const BASE_URL: string = 'http://192.168.1.130:8080';
const PREFERENCES_NAME: string = 'user_login_data';
const KEY_TOKEN: string = 'token';
const KEY_USER_INFO: string = 'user_info';

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

export interface ApiResponse<T = Object> {
  code: number;
  message: string;
  data: T | null;
}

export interface RequestError {
  code: number;
  message: string;
  name?: string;
}

export interface ErrorDetail {
  code: number;
  message: string;
}

export interface HttpRequestOptions {
  method?: http.RequestMethod;
  header?: Record<string, string>;
  extraData?: string | Object;
  connectTimeout?: number;
  readTimeout?: number;
}

export interface TokenResult {
  token: string;
}

//增加注册请求接口
export interface RegisterRequest {
  phone: string;
  code: string;
  password: string;
}

// ==================== 持久化管理器 ====================
class PreferencesManager {
  private static instance: PreferencesManager;
  private preferences: preferences.Preferences | null = null;
  private initialized: boolean = false;

  public static getInstance(): PreferencesManager {
    if (!PreferencesManager.instance) {
      PreferencesManager.instance = new PreferencesManager();
    }
    return PreferencesManager.instance;
  }

  async init(context: Context): Promise<void> {
    if (this.initialized && this.preferences !== null) {
      return;
    }

    try {
      this.preferences = await preferences.getPreferences(context, PREFERENCES_NAME);
      this.initialized = true;
      console.log('Preferences初始化成功');
    } catch (err) {
      console.error('Preferences初始化失败:', err);
      const error = new Error('Preferences初始化失败');
      throw error;
    }
  }

  async saveToken(token: string): Promise<void> {
    if (!this.preferences) {
      console.error('Preferences未初始化');
      return;
    }
    try {
      await this.preferences.put(KEY_TOKEN, token);
      await this.preferences.flush();
      console.log('Token保存成功');
    } catch (err) {
      console.error('Token保存失败:', err);
    }
  }

  async getToken(): Promise<string> {
    if (!this.preferences) {
      console.error('Preferences未初始化');
      return '';
    }
    try {
      const token = await this.preferences.get(KEY_TOKEN, '');
      return token as string;
    } catch (err) {
      console.error('Token读取失败:', err);
      return '';
    }
  }

  async saveUserInfo(userInfo: UserInfo): Promise<void> {
    if (!this.preferences) {
      console.error('Preferences未初始化');
      return;
    }
    try {
      await this.preferences.put(KEY_USER_INFO, JSON.stringify(userInfo));
      await this.preferences.flush();
      console.log('用户信息保存成功');
    } catch (err) {
      console.error('用户信息保存失败:', err);
    }
  }

  async getUserInfo(): Promise<UserInfo | null> {
    if (!this.preferences) {
      console.error('Preferences未初始化');
      return null;
    }
    try {
      const userInfoStr = await this.preferences.get(KEY_USER_INFO, '');
      if (userInfoStr && typeof userInfoStr === 'string' && userInfoStr !== '') {
        return JSON.parse(userInfoStr) as UserInfo;
      }
      return null;
    } catch (err) {
      console.error('用户信息读取失败:', err);
      return null;
    }
  }

  async clear(): Promise<void> {
    if (!this.preferences) {
      console.error('Preferences未初始化');
      return;
    }
    try {
      await this.preferences.clear();
      await this.preferences.flush();
      console.log('Preferences清除成功');
    } catch (err) {
      console.error('Preferences清除失败:', err);
    }
  }

  async isLoggedIn(): Promise<boolean> {
    const token = await this.getToken();
    const userInfo = await this.getUserInfo();
    return token !== '' && userInfo !== null;
  }
}

// ==================== 配置管理器 ====================
export class ConfigManager {
  private static token: string = '';
  private static userInfo: UserInfo | null = null;
  private static prefsManager = PreferencesManager.getInstance();

  // 初始化:从持久化存储加载数据
  static async init(context: Context): Promise<void> {
    await ConfigManager.prefsManager.init(context);
    ConfigManager.token = await ConfigManager.prefsManager.getToken();
    ConfigManager.userInfo = await ConfigManager.prefsManager.getUserInfo();
    console.log('ConfigManager初始化完成, Token存在:', ConfigManager.token !== '');
  }

  static async setToken(token: string): Promise<void> {
    ConfigManager.token = token;
    await ConfigManager.prefsManager.saveToken(token);
  }

  static getToken(): string {
    return ConfigManager.token;
  }

  static async setUserInfo(userInfo: UserInfo): Promise<void> {
    ConfigManager.userInfo = userInfo;
    await ConfigManager.prefsManager.saveUserInfo(userInfo);
  }

  static getUserInfo(): UserInfo | null {
    return ConfigManager.userInfo;
  }

  static async clear(): Promise<void> {
    ConfigManager.token = '';
    ConfigManager.userInfo = null;
    await ConfigManager.prefsManager.clear();
  }

  static isLoggedIn(): boolean {
    return ConfigManager.token !== '' && ConfigManager.userInfo !== null;
  }

  // 从持久化存储检查登录状态
  static async checkLoginStatus(): Promise<boolean> {
    return await ConfigManager.prefsManager.isLoggedIn();
  }
}

// ==================== UserStore 类 ====================
export class UserStore {
  private static instance: UserStore;
  private uiContext: UIContext | null = null;

  public static getInstance(): UserStore {
    if (!UserStore.instance) {
      UserStore.instance = new UserStore();
    }
    return UserStore.instance;
  }

  init(uiContext: UIContext): void {
    this.uiContext = uiContext;
  }

  handleLogout(message: string): void {
    ConfigManager.clear();

    promptAction.showToast({
      message: message,
      duration: 3000,
      bottom: 300
    });

    try {
      if (this.uiContext) {
        const router = this.uiContext.getRouter();
        router.replaceUrl({ url: 'pages/Index' });
      } else {
        router.replaceUrl({ url: 'pages/Index' });
      }
    } catch (err) {
      console.error('强制退出跳转失败:', err);
    }
  }

  get isLoggedIn(): boolean {
    return ConfigManager.isLoggedIn();
  }

  async loginSuccess(userInfo: UserInfo, token: string): Promise<void> {
    await ConfigManager.setUserInfo(userInfo);
    await ConfigManager.setToken(token);
  }

  logout(): void {
    ConfigManager.clear();
    if (this.uiContext) {
      try {
        const router = this.uiContext.getRouter();
        if (router) {
          router.replaceUrl({
            url: 'pages/Index'
          });
        }
      } catch (error) {
        console.error('跳转登录页失败:', error);
      }
    }
  }

  getUiContext(): UIContext | null {
    return this.uiContext;
  }
}

// ==================== HTTP请求工具类 ====================
class HttpRequest {
  private http: http.HttpRequest;

  constructor() {
    this.http = http.createHttp();
  }

  async request<T>(url: string, options: HttpRequestOptions): Promise<ApiResponse<T>> {
    return new Promise((resolve, reject) => {
      const headers: Record<string, string> = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      const token = ConfigManager.getToken();
      if (token) {
        headers['Authorization'] = `Bearer ${token}`;
      }

      if (options.header) {
        if (options.header['Custom-Header']) {
          headers['Custom-Header'] = options.header['Custom-Header'];
        }
        if (options.header['X-Requested-With']) {
          headers['X-Requested-With'] = options.header['X-Requested-With'];
        }
      }

      const requestOptions: http.HttpRequestOptions = {
        method: options.method || http.RequestMethod.GET,
        header: headers,
        extraData: options.extraData,
        connectTimeout: options.connectTimeout || 10000,
        readTimeout: options.readTimeout || 10000
      };

      this.http.request(BASE_URL + url, requestOptions)
        .then((response: http.HttpResponse) => {
          console.info(`[HTTP] ${url} - 状态码: ${response.responseCode}`);

          if (response.responseCode === 401) {
            console.warn('[HTTP] 401 Unauthorized - Token过期或无效');
            UserStore.getInstance().handleLogout('登录已过期');
            reject({ code: 401, message: 'Expired' });
            return;
          }

          if (response.responseCode === 409) {
            console.warn('[HTTP] 409 Conflict - 账号在其他设备登录');
            UserStore.getInstance().handleLogout('您的账号已在其他设备登录');
            reject({ code: 409, message: 'Conflict' });
            return;
          }

          if (response.responseCode === 200) {
            let res: ApiResponse<T> = JSON.parse(response.result.toString());
            console.info(`[HTTP] 业务Code: ${res.code}, Message: ${res.message}`);

            if (res.code === 409) {
              console.warn('[HTTP] 业务层409 - 账号在其他设备登录');
              UserStore.getInstance().handleLogout('您的账号已在其他设备登录');
              reject(res);
            } else {
              resolve(res);
            }
          } else {
            console.error(`[HTTP] 服务器异常: ${response.responseCode}`);
            reject(new Error(`服务器异常: ${response.responseCode}`));
          }
        })
        .catch((err: Error) => {
          console.error(`[HTTP] 网络层错误: ${JSON.stringify(err)}`);
          reject(err);
        });
    });
  }

  destroy(): void {
    this.http.destroy();
  }
}

// ==================== API服务 ====================
export class ApiService {
  private static httpRequest = new HttpRequest();

  static async login(phone: string, password: string): Promise<LoginResponse> {
    const requestData: LoginRequest = {
      phone: phone,
      password: password
    };

    const requestBody: string = JSON.stringify(requestData);

    try {
      const response = await ApiService.httpRequest.request<LoginData>('/api/login', {
        method: http.RequestMethod.POST,
        extraData: requestBody,
      });

      if (response.code === 200 && response.data) {
        await ConfigManager.setToken(response.data.token);
        await ConfigManager.setUserInfo(response.data.userInfo);
      }

      return {
        code: response.code,
        message: response.message,
        data: response.data
      };
    } catch (error) {
      if (error instanceof Error) {
        throw error;
      } else {
        throw new Error('登录请求失败');
      }
    }
  }

  static async getUserInfo(): Promise<ApiResponse<UserInfo>> {
    return await ApiService.httpRequest.request<UserInfo>('/api/user/info', {
      method: http.RequestMethod.GET
    });
  }

  static async refreshToken(): Promise<ApiResponse<TokenResult>> {
    return await ApiService.httpRequest.request<TokenResult>('/api/auth/refresh', {
      method: http.RequestMethod.POST
    });
  }

  // 新增:校验Token有效性
  static async validateToken(): Promise<ApiResponse<string>> {
    return await ApiService.httpRequest.request<string>('/api/auth/validate-token', {
      method: http.RequestMethod.GET
    });
  }

  /**
   * 发送验证码
   */
  static async sendCode(phone: string): Promise<ApiResponse<string>> {
    return await ApiService.httpRequest.request<string>('/api/send-code', {
      method: http.RequestMethod.POST,
      extraData: JSON.stringify({ phone: phone })
    });
  }

  /**
   * 用户注册
   */
  static async register(phone: string, code: string, password: string): Promise<ApiResponse<string>> {
    const requestData: RegisterRequest = {
      phone: phone,
      code: code,
      password: password
    };

    return await ApiService.httpRequest.request<string>('/api/register', {
      method: http.RequestMethod.POST,
      extraData: JSON.stringify(requestData)
    });
  }
}