import { promptAction } from '@kit.ArkUI';
import { BusinessError } from '@ohos.base';
import { ApiService, ConfigManager } from '../utils/HttpUtil';
@Entry
@Component
struct Index {
  @State message: string = '登录测试';
  @State account: string = '';
  @State password: string = '';
  @State isLoading: boolean = false;
  //校验错误提示，用于显示错误
  @State phoneError: string = '';
  @State pwdError: string = '';

  //缓存UIContext
  private cachedUiContext: UIContext | null = null;

  //apiService和configManager


  //组件初始化时获取UIContext（）
  aboutToAppear() {
    try {
      // Stage模式获取UIContext的正确方式
      this.cachedUiContext = this.getUIContext();
      console.log('Stage模式UIContext缓存成功：', !!this.cachedUiContext);
    } catch (err) {
      const error = err as BusinessError;
      console.error('获取Stage模式UIContext失败：', error.message);
      this.cachedUiContext = null;
    }
  }

  //手机号正则校验方法
  private validatePhone(phone: string): boolean {
    //1开头，第二位3-9，后面9位数字
    const phoneReg = /^1[3-9]\d{9}$/;
    //前置校验是否为空或位数不足
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
    //前置校验是否为空
    if (pwd.trim() === '') {
      this.pwdError = '请输入密码';
      return false;
    }
    // 长度校验：6-13位
    if (pwd.length < 6 || pwd.length > 13) {
      this.pwdError = '密码长度需为6-13位';
      return false;
    }
    // 复杂度校验：必须包含数字、字母、标点符号
    const hasNumber = /\d/.test(pwd); // 包含数字
    const hasLetter = /[a-zA-Z]/.test(pwd); // 包含字母
    const hasSymbol = /[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?~`]/.test(pwd); // 包含常见标点

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

  // 登录方法，包含账号密码复杂校验和加载态控制
  private async goLogin(): Promise<void> {
    //加载态拦截,防止重复点击
    if (this.isLoading) {
      console.log('登录请求中，请勿重复点击');
      return;
    }

    //前端校验
    const isPhoneValid = this.validatePhone(this.account);
    const isPwdValid = this.validatePassword(this.password);
    if (!isPhoneValid || !isPwdValid) {
      // 若有校验错误，直接返回，错误提示已通过@State实时显示
      return;
    }

    //开启加载态，锁死按钮
    this.isLoading = true;

    try {
      this.isLoading = true;
      console.log("准备登录: " + this.account);

      const response = await ApiService.login(this.account, this.password);
      console.log("登录响应: " + JSON.stringify(response));

      if (response.code === 200 && response.data) {
        ConfigManager.setToken(response.data.token);
        ConfigManager.setUserInfo(response.data.userInfo);
        promptAction.openToast({ message: '登录成功' });

        console.log("准备跳转到主页");
        try {
          if (this.cachedUiContext !== null) {
            const router = this.cachedUiContext.getRouter();
            if (router && typeof router.replaceUrl === 'function') {
              router.replaceUrl({ url: 'pages/MainPage' });
              console.log("跳转成功");
            } else {
              throw new Error('Router.replaceUrl方法不存在或无效');
            }
          } else {
            throw new Error('UiContext为空，无法跳转');
          }
        } catch (err) {
          const error = err as BusinessError;
          console.error('跳转主页失败：', error);
          this.handleRouterError(error);
          try {
            if (this.cachedUiContext !== null) {
              const router = this.cachedUiContext.getRouter();
              if (router && typeof router.pushUrl === 'function') {
                router.pushUrl({ url: 'pages/MainPage' });
                console.log('兜底跳转成功');
              }
            }
          } catch (err2) {
            console.error('兜底跳转也失败：', err2);
            promptAction.openToast({ message: '登录成功，但页面跳转失败，请手动返回首页' });
          }
        }
      } else {
        promptAction.openToast({ message: response.message || '登录失败' });
      }
    } catch (error) {
      const err = error as BusinessError;
      console.error("登录错误:", JSON.stringify(err));
      if (err.code === 100001) {
        promptAction.openToast({ message: '页面跳转异常，请重试' });
      } else {
        promptAction.openToast({ message: '网络请求失败，请检查连接' });
      }
    } finally {
      //无论成功失败，最后关闭加载态
      this.isLoading = false;
      console.log('登录请求结束，恢复按钮可点击');
    }
  }

  handleRouterError(error: BusinessError<void>) {
    throw new Error('Method not implemented.');
  }

  build() {
    Column({ space: 16 }) {
      //登录主标题
      Text(this.message)
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 48, bottom: 24 })

      //手机号账号输入区
      Text('账号:')
        .fontSize(20)
        .fontColor('#333')
        .width('100%')  // 文本宽度适配容器
        .textAlign(TextAlign.Start) // 左对齐优化
      TextInput({ placeholder: '请输入手机号', text: this.account })
        .onChange((value: string) => {
          this.account = value // 状态更新
          // 实时校验
          this.validatePhone(value);
        })
        .width('100%')
        .height(48)
        .borderRadius(24)
        .backgroundColor('#F5F5F5')
        .padding({ left: 16, right: 16 })  // 增加右侧内边距
        .enabled(!this.isLoading) // 加载时禁用输入框
      // 手机号错误提示
      if (this.phoneError) {
        Text(this.phoneError)
          .fontSize(12)
          .fontColor('#ff4d4f') //红色小字
          .margin({ bottom: 8, left: 2 })
      }

      //密码输入区
      Text('密码:')
        .fontSize(20)
        .fontColor('#333')
        .width('100%')  // 文本宽度适配容器
        .textAlign(TextAlign.Start) // 左对齐优化
      TextInput({ placeholder: '请输入密码', text: this.password })
        .onChange((value: string) => {
          this.password = value // 状态更新
          // 实时校验
          this.validatePassword(value);
        })
        .width('100%')
        .height(48)
        .borderRadius(24)
        .backgroundColor('#F5F5F5')
        .padding({ left: 16, right: 16 })  // 增加右侧内边距
        .enabled(!this.isLoading) // 加载时禁用输入框
      // 密码错误提示
      if (this.pwdError) {
        Text(this.pwdError)
          .fontSize(12)
          .fontColor('#ff4d4f') //红色小字
          .margin({ bottom: 8, left: 2 })
      }

      //登录按钮
      /*Button(this.isLoading ? '登录中...' :'登录', { type: ButtonType.Capsule })  // 使用胶囊按钮规范

        .width('100%')
        .height(50)
        .margin({ top: 8 })
        .backgroundColor('#007DFF')
        .fontColor(Color.White)
        .enabled(!this.isLoading) // 加载时禁用按钮点击
        .backgroundColor(this.isLoading ? '#999999' : '#007dff') // 加载时按钮变灰
        .onClick(() => this.goLogin())*/

      Button() {
        if (this.isLoading) {
          // 加载中显示
          Row({ space: 8 }) {
            LoadingProgress() // 加载动画组件
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
      .enabled(!this.isLoading) // 加载时禁用按钮点击
      .backgroundColor(this.isLoading ? '#999999' : '#007dff') // 加载时按钮变灰
      .onClick(() => this.goLogin())
    }
    .padding(24)
    .height('100%')
    .width('100%')
  }


  private navigateToPage(url: string): void {
    console.log(`准备跳转到：${url}`);
    if (!this.cachedUiContext) {
      return;
    }
    try {
      const router = this.cachedUiContext.getRouter();
      if (router && typeof router.pushUrl === 'function') {
        router.pushUrl({ url: url });
        console.log("跳转成功");
      } else {
        throw new Error('Router.pushUrl方法不存在或无效');
      }
    } catch (err) {
      const error = err as BusinessError;
      this.handleRouterError(error);
    }
  }

  /*// 统一处理路由错误
  private handleRouterError(error: BusinessError): void {
    console.error(`路由错误[${error.code}]：`, error.message);
    if (!this.cachedUiContext) return;
    switch (error.code) {
      case 401:
        this.cachedUiContext.getPromptAction().openToast({ message: '参数错误' });
        break;
      case 100001:
        this.cachedUiContext.getPromptAction().openToast({ message: '系统错误，请重试' });
        break;
      case 100002:
      case 200002:
        this.cachedUiContext.getPromptAction().openToast({ message: '页面不存在' });
        break;
      case 100003:
        this.cachedUiContext.getPromptAction().openToast({ message: '页面过多，请返回后重试' });
        break;
      default:
        this.cachedUiContext.getPromptAction().openToast({ message: '操作失败，请重试' });
    }
  }*/
}