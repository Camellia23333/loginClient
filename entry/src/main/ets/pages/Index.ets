import { promptAction } from '@kit.ArkUI';
import { BusinessError } from '@ohos.base';
import type { UIContext } from '@ohos.arkui.UIContext';
//适配HttpUtil的导出类型
import { ApiService, ConfigManager, LoginResponse, UserInfo } from '../utils/HttpUtil';

// 定义跳转参数类型，解决untyped-obj-literals报错
interface NavigateParams {
  username: string;
  phone: string;
}

@Entry
@Component
struct Index {
  @State message: string = '登录测试';
  @State account: string = '';
  @State password: string = '';
  @State isLoading: boolean = false;
  @State phoneError: string = '';
  @State pwdError: string = '';

  // 缓存UIContext
  private cachedUiContext: UIContext | null = null;

  // 防抖定时器ID
  private debounceTimer: number = -1;
  // 最后点击时间戳
  private lastClickTime: number = 0;
  // 点击间隔限制(毫秒)
  private readonly CLICK_INTERVAL: number = 2000;

  // 组件初始化时获取UIContext
  aboutToAppear(): void {
    try {
      this.cachedUiContext = this.getUIContext();
      console.log('Stage模式UIContext缓存成功：', !!this.cachedUiContext);
    } catch (err) {
      const error = err as BusinessError;
      console.error('获取Stage模式UIContext失败：', error.message);
      this.cachedUiContext = null;
    }
  }

  // 组件销毁时清理定时器
  aboutToDisappear(): void {
    if (this.debounceTimer !== -1) {
      clearTimeout(this.debounceTimer);
      this.debounceTimer = -1;
    }
  }

  // 手机号正则校验方法
  private validatePhone(phone: string): boolean {
    const phoneReg = /^1[3-9]\d{9}$/;
    if (phone.trim() === '') {
      this.phoneError = '请输入手机号';
      return false;
    }
    if (!phoneReg.test(phone)) {
      this.phoneError = '请输入正确的11位手机号';
      return false;
    }
    this.phoneError = '';
    return true;
  }

  // 密码复杂度校验
  private validatePassword(pwd: string): boolean {
    if (pwd.trim() === '') {
      this.pwdError = '请输入密码';
      return false;
    }
    if (pwd.length < 6 || pwd.length > 13) {
      this.pwdError = '密码长度需为6-13位';
      return false;
    }
    const hasNumber = /\d/.test(pwd);
    const hasLetter = /[a-zA-Z]/.test(pwd);
    const hasSymbol = /[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?~`]/.test(pwd);

    if (!hasNumber) {
      this.pwdError = '密码必须包含数字';
      return false;
    }
    if (!hasLetter) {
      this.pwdError = '密码必须包含字母';
      return false;
    }
    if (!hasSymbol) {
      this.pwdError = '密码必须包含标点符号';
      return false;
    }
    this.pwdError = '';
    return true;
  }

  // 登录按钮点击处理
  private onLoginClick(): void {
    const currentTime = Date.now();

    // 时间戳节流
    if (currentTime - this.lastClickTime < this.CLICK_INTERVAL) {
      console.log('点击过于频繁，请稍后再试');
      promptAction.openToast({ message: '操作过于频繁，请稍后再试' });
      return;
    }

    // 加载态拦截
    if (this.isLoading) {
      console.log('登录请求中，请勿重复点击');
      return;
    }

    // 更新最后点击时间
    this.lastClickTime = currentTime;

    // 定时器防抖
    if (this.debounceTimer !== -1) {
      clearTimeout(this.debounceTimer);
    }

    //直接使用number
    this.debounceTimer = setTimeout(() => {
      this.goLogin();
    }, 300);
  }

  // 登录方法
  private async goLogin(): Promise<void> {
    // 前端校验
    const isPhoneValid = this.validatePhone(this.account);
    const isPwdValid = this.validatePassword(this.password);
    if (!isPhoneValid || !isPwdValid) {
      return;
    }

    // 开启加载态
    this.isLoading = true;
    console.log("准备登录: " + this.account);

    try {
      const response: LoginResponse = await ApiService.login(this.account, this.password);
      console.log("登录响应: " + JSON.stringify(response));

      if (response.code === 200 && response.data) {
        // 保存登录信息
        ConfigManager.setToken(response.data.token);
        ConfigManager.setUserInfo(response.data.userInfo); // 类型完全匹配

        promptAction.openToast({ message: '登录成功' });
        console.log("准备跳转到欢迎页");

        // 延迟跳转
        setTimeout(() => {
          this.navigateToWelcome();
        }, 500);

      } else {
        promptAction.openToast({ message: response.message || '登录失败' });
        this.isLoading = false;
      }
    } catch (error) {
      const err = error as BusinessError;
      console.error("登录错误:", JSON.stringify(err));
      promptAction.openToast({ message: '网络请求失败，请检查连接' });
      this.isLoading = false;
    }
  }

  // 跳转到欢迎页
  private navigateToWelcome(): void {
    console.log("准备跳转到欢迎页");

    //适配HttpUtil的UserInfo类型字段
    const userInfo = ConfigManager.getUserInfo();
    const params: NavigateParams = {
      username: userInfo?.username || '用户', // 使用UserInfo的username字段
      phone: this.account
    };

    try {
      if (this.cachedUiContext !== null) {
        const router = this.cachedUiContext.getRouter();
        if (router && typeof router.replaceUrl === 'function') {
          router.replaceUrl({
            url: 'pages/WelcomePage',
            params: params // 显式NavigateParams类型
          });
          console.log("replaceUrl跳转成功");
        } else {
          throw new Error('Router.replaceUrl方法不存在或无效');
        }
      } else {
        throw new Error('UIContext为空，无法跳转');
      }
    } catch (err) {
      const error = err as BusinessError;
      console.error('跳转欢迎页失败：', error.message);
      this.handleRouterError(error);

      // 兜底跳转
      this.fallbackNavigate(params);
    } finally {
      // 恢复按钮状态
      setTimeout(() => {
        this.isLoading = false;
      }, 500);
    }
  }

  // 兜底跳转方法
  private fallbackNavigate(params: NavigateParams): void {
    try {
      if (this.cachedUiContext !== null) {
        const router = this.cachedUiContext.getRouter();
        if (router && typeof router.pushUrl === 'function') {
          router.pushUrl({
            url: 'pages/WelcomePage',
            params: params
          });
          console.log('兜底pushUrl跳转成功');
        }
      }
    } catch (err2) {
      const error = err2 as BusinessError;
      console.error('兜底跳转也失败：', error.message);
      promptAction.openToast({ message: '登录成功，但页面跳转失败' });
    }
  }

  // 统一处理路由错误
  private handleRouterError(error: BusinessError): void {
    console.error(`路由错误[${error.code}]：`, error.message);

    if (!this.cachedUiContext) {
      promptAction.openToast({ message: '系统错误，请重试' });
      return;
    }

    try {
      const promptActionCtx = this.cachedUiContext.getPromptAction();

      switch (error.code) {
        case 401:
          promptActionCtx.openToast({ message: '参数错误' });
          break;
        case 100001:
          promptActionCtx.openToast({ message: '系统错误，请重试' });
          break;
        case 100002:
        case 200002:
          promptActionCtx.openToast({ message: '页面不存在' });
          break;
        case 100003:
          promptActionCtx.openToast({ message: '页面过多，请返回后重试' });
          break;
        default:
          promptActionCtx.openToast({ message: '操作失败，请重试' });
      }
    } catch (e) {
      const error = e as BusinessError;
      console.error('获取PromptAction失败：', error.message);
      promptAction.openToast({ message: '操作失败，请重试' });
    }
  }

  // 通用页面跳转方法，显式类型
  private navigateToPage(url: string, params?: NavigateParams): void {
    console.log(`准备跳转到：${url}`);

    if (!this.cachedUiContext) {
      promptAction.openToast({ message: '系统错误，无法跳转' });
      return;
    }

    try {
      const router = this.cachedUiContext.getRouter();
      if (router && typeof router.pushUrl === 'function') {
        router.pushUrl({
          url: url,
          params: params
        });
        console.log("跳转成功");
      } else {
        throw new Error('Router.pushUrl方法不存在或无效');
      }
    } catch (err) {
      const error = err as BusinessError;
      this.handleRouterError(error);
    }
  }

  build() {
    Column({ space: 16 }) {
      // 登录主标题
      Text(this.message)
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 48, bottom: 24 })

      // 手机号输入区
      Text('账号:')
        .fontSize(20)
        .fontColor('#333')
        .width('100%')
        .textAlign(TextAlign.Start)

      TextInput({ placeholder: '请输入手机号', text: this.account })
        .type(InputType.PhoneNumber)
        .onChange((value: string) => {
          this.account = value;
          this.validatePhone(value);
        })
        .width('100%')
        .height(48)
        .borderRadius(24)
        .backgroundColor('#F5F5F5')
        .padding({ left: 16, right: 16 })
        .enabled(!this.isLoading)

      // 手机号错误提示
      if (this.phoneError) {
        Text(this.phoneError)
          .fontSize(12)
          .fontColor('#ff4d4f')
          .width('100%')
          .textAlign(TextAlign.Start)
          .margin({ bottom: 8, left: 2 })
      }

      // 密码输入区
      Text('密码:')
        .fontSize(20)
        .fontColor('#333')
        .width('100%')
        .textAlign(TextAlign.Start)

      TextInput({ placeholder: '请输入密码', text: this.password })
        .type(InputType.Password)
        .onChange((value: string) => {
          this.password = value;
          this.validatePassword(value);
        })
        .width('100%')
        .height(48)
        .borderRadius(24)
        .backgroundColor('#F5F5F5')
        .padding({ left: 16, right: 16 })
        .enabled(!this.isLoading)

      // 密码错误提示
      if (this.pwdError) {
        Text(this.pwdError)
          .fontSize(12)
          .fontColor('#ff4d4f')
          .width('100%')
          .textAlign(TextAlign.Start)
          .margin({ bottom: 8, left: 2 })
      }

      // 登录按钮，加载态视觉反馈
      Button() {
        if (this.isLoading) {
          Row({ space: 8 }) {
            LoadingProgress()
              .color('#ffffff')
              .width(20)
              .height(20)
            Text('登录中...')
              .fontSize(18)
              .fontColor('#ffffff')
          }
        } else {
          Text('登录')
            .fontSize(18)
            .fontColor('#ffffff')
        }
      }
      .width('100%')
      .height(48)
      .borderRadius(8)
      .margin({ top: 16 })
      .backgroundColor(this.isLoading ? '#999999' : '#007dff')
      .enabled(!this.isLoading)
      .onClick(() => {
        this.onLoginClick();
      })
    }
    .padding(24)
    .height('100%')
    .width('100%')
    .backgroundColor('#FFFFFF')
  }
}