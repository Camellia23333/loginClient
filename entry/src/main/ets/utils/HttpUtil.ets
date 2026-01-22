// utils/HttpUtil.ets
import http from '@ohos.net.http';
import { promptAction, router } from '@kit.ArkUI';
import type { UIContext } from '@ohos.arkui.UIContext';
import { BusinessError } from '@kit.BasicServicesKit';

// ==================== 配置常量 ====================
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

// 定义错误详情类型
export interface ErrorDetail {
  code: number;
  message: string;
}

// 定义请求选项类型
export interface HttpRequestOptions {
  method?: http.RequestMethod;
  header?: Record<string, string>;
  extraData?: string | Object;
  connectTimeout?: number;
  readTimeout?: number;
}

//定义刷新Token的返回结构，解决 Object literals 报错
export interface TokenResult {
  token: string;
}

// ==================== 配置管理器 ====================
export class ConfigManager {
  private static token: string = '';
  private static userInfo: UserInfo | null = null;

  static setToken(token: string): void {
    ConfigManager.token = token;
  }

  static getToken(): string {
    return ConfigManager.token;
  }

  static setUserInfo(userInfo: UserInfo): void {
    ConfigManager.userInfo = userInfo;
  }

  static getUserInfo(): UserInfo | null {
    return ConfigManager.userInfo;
  }

  static clear(): void {
    ConfigManager.token = '';
    ConfigManager.userInfo = null;
  }

  static isLoggedIn(): boolean {
    return ConfigManager.token !== '' && ConfigManager.userInfo !== null;
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

  //更新 UIContext
  init(uiContext: UIContext): void {
    this.uiContext = uiContext;
  }

  // 执行强制退出逻辑
  handleLogout(message: string): void {
    ConfigManager.clear(); // 清除本地Token

    // 提示用户
    promptAction.showToast({
      message: message,
      duration: 3000,
      bottom: 300 // 显示在屏幕中间偏下方
    });

    // 跳转回登录页
    // 优先使用 UIContext 跳转，如果不存在则尝试全局 router
    try {
      if (this.uiContext) {
        const router = this.uiContext.getRouter();
        router.replaceUrl({ url: 'pages/Index' }); // 使用 replaceUrl 防止用户点返回键回到受保护页面
      } else {
        // 兜底方案
        router.replaceUrl({ url: 'pages/Index' });
      }
    } catch (err) {
      console.error('强制退出跳转失败:', err);
    }
  }

  get isLoggedIn(): boolean {
    return ConfigManager.isLoggedIn();
  }

  loginSuccess(userInfo: UserInfo, token: string): void {
    ConfigManager.setUserInfo(userInfo);
    ConfigManager.setToken(token);
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
    // 保存当前实例的引用
    const self = this;

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

      /*self.http.request(BASE_URL + url, requestOptions)
        .then((response: http.HttpResponse) => {
          // ==========状态码拦截 ==========
          if (response.responseCode === 401) {
            // Token 过期 / 无效
            UserStore.getInstance().handleLogout('登录已过期，请重新登录');
            reject({ code: 401, message: '登录已过期' });

          } else if (response.responseCode === 409) {
            // 互踢，唯一登录冲突
            UserStore.getInstance().handleLogout('您的账号已在其他设备登录，请重新登录');
            reject({ code: 409, message: '账号异地登录' });

          } else if (response.responseCode === 200) {
            // 请求成功
            try {
              let resultStr: string = '';
              if (typeof response.result === 'string') {
                resultStr = response.result;
              } else {
                resultStr = JSON.stringify(response.result);
              }
              const parsedResult: ApiResponse<T> = JSON.parse(resultStr);

              // 业务层面的错误码处理 ，假设后端 200 里也可能包着 code!=200
              if(parsedResult.code !== 200) {
                // 如果后端在 200 响应中返回了 401/409 的业务码，也在这里处理
                if (parsedResult.code === 401) {
                  UserStore.getInstance().handleLogout('登录已过期');
                  reject(parsedResult);
                  return;
                }
              }
              resolve(parsedResult);
            } catch (parseErr) {
              reject(new Error('响应数据解析失败'));
            }
          } else {
            // 其他 HTTP 错误
            reject(new Error(`HTTP Error: ${response.responseCode}`));
          }
        })
        .catch((err: Error) => {
          reject(err);
        });*/
      //添加拦截器
      this.http.request(BASE_URL + url, requestOptions)
        .then((response: http.HttpResponse) => {
          console.info(`收到响应，状态码: ${response.responseCode}`);

          //显式拦截 401 和 409
          if (response.responseCode === 401) {
            UserStore.getInstance().handleLogout('登录已过期');
            reject({ code: 401, message: 'Expired' });
            return;
          }

          if (response.responseCode === 409) {
            // 这里就是互踢的逻辑
            UserStore.getInstance().handleLogout('您的账号已在其他设备登录');
            reject({ code: 409, message: 'Conflict' });
            return;
          }

          if (response.responseCode === 200) {
            // 解析 200 情况下的业务 code
            let res: ApiResponse<T> = JSON.parse(response.result.toString());
            if (res.code === 409) { // 兼容后端在200里返回409的情况
              UserStore.getInstance().handleLogout('您的账号已在其他设备登录');
              reject(res);
            } else {
              resolve(res);
            }
          } else {
            reject(new Error(`服务器异常: ${response.responseCode}`));
          }
        })
        .catch((err: Error) => {
          // 如果走到这里，说明是网络不通（连接超时、拒绝连接等）
          console.error(`网络层错误: ${JSON.stringify(err)}`);
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
      // 【修改点】将 this.httpRequest 改为 ApiService.httpRequest
      const response = await ApiService.httpRequest.request<LoginData>('/api/login', {
        method: http.RequestMethod.POST,
        extraData: requestBody,
      });

      if (response.code === 200 && response.data) {
        ConfigManager.setToken(response.data.token);
        ConfigManager.setUserInfo(response.data.userInfo);
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
    // this.httpRequest 改为 ApiService.httpRequest
    return await ApiService.httpRequest.request<UserInfo>('/api/user/info', {
      method: http.RequestMethod.GET
    });
  }

  //泛型类型改为具名接口 TokenResult，解决对象字面量报错
  static async refreshToken(): Promise<ApiResponse<TokenResult>> {
    return await ApiService.httpRequest.request<TokenResult>('/api/auth/refresh', {
      method: http.RequestMethod.POST
    });
  }
}