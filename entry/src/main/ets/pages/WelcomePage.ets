import { promptAction } from '@kit.ArkUI';
import { BusinessError } from '@ohos.base';
import { ApiService, ConfigManager, UserStore } from '../utils/HttpUtil';

interface RouterParams {
  username: string;
  phone: string;
}

@Entry
@Component
struct WelcomePage {
  @State username: string = '';
  @State phone: string = '';
  @State currentTime: string = '';
  @State isRefreshing: boolean = false;
  @State lastCheckTime: string = '';

  private cachedUiContext: UIContext | null = null;
  private timeUpdateTimer: number = -1;

  async aboutToAppear(): Promise<void> {
    try {
      this.cachedUiContext = this.getUIContext();

      // 获取Context
      const context = this.cachedUiContext.getHostContext();
      if (!context) {
        console.error('获取Context失败');
        return;
      }

      // 初始化ConfigManager
      await ConfigManager.init(context);

      // 初始化UserStore
      if (this.cachedUiContext) {
        UserStore.getInstance().init(this.cachedUiContext);
      }
    } catch (err) {
      console.error('UIContext init failed', err);
    }

    // 加载数据
    this.initData();

    // 更新当前时间
    this.updateTime();

    // 每秒更新一次时间显示
    this.timeUpdateTimer = setInterval(() => {
      this.updateTime();
    }, 1000);

    // 应用重启恢复到欢迎页时,主动发起一次Token校验
    await this.checkTokenOnStartup();
  }

  aboutToDisappear(): void {
    if (this.timeUpdateTimer !== -1) {
      clearInterval(this.timeUpdateTimer);
    }
  }

  // 从路由参数或缓存加载数据
  private initData() {
    try {
      if (this.cachedUiContext !== null) {
        const router = this.cachedUiContext.getRouter();
        const params = router.getParams() as RouterParams;
        if (params && params.username) {
          this.username = params.username;
          this.phone = params.phone || '';
          console.log('从路由参数加载用户信息');
          return;
        }
      }
    } catch (err) {
      console.error('获取路由参数失败:', err);
    }

    // 如果路由参数为空,从ConfigManager获取
    const userInfo = ConfigManager.getUserInfo();
    if (userInfo) {
      this.username = userInfo.username || '用户';
      this.phone = userInfo.phone || '';
      console.log('从ConfigManager加载用户信息');
    } else {
      this.username = '用户';
      this.phone = '';
      console.log('未找到用户信息');
    }
  }

  // 应用启动时检查Token状态
  private async checkTokenOnStartup(): Promise<void> {
    console.log('=== 应用启动Token校验开始 ===');
    console.log('当前Token:', ConfigManager.getToken().substring(0, 20) + '...');

    // 延迟500ms再校验,确保登录流程完全结束
    await new Promise<void>((resolve) => setTimeout(resolve, 500));

    try {
      const response = await ApiService.validateToken();
      console.log('Token校验响应:', JSON.stringify(response));

      if (response.code === 200) {
        console.log('✓ Token校验通过,连接正常');
        this.lastCheckTime = this.formatTime(new Date());
      } else {
        console.warn('Token校验返回非200状态:', response.code, response.message);
      }
    } catch (error) {
      const err = error as BusinessError;
      console.error('Token校验失败 - Code:', err.code, 'Message:', err.message);

      // HttpUtil的拦截器会自动处理401和409,这里只处理其他网络错误
      if (err.code !== 401 && err.code !== 409) {
        console.error('网络连接失败,但不影响页面显示');
      } else {
        console.error('Token失效,即将跳转到登录页');
      }
    }

    console.log('=== Token校验结束 ===');
  }

  // 手动刷新Token状态
  private async refreshTokenStatus(): Promise<void> {
    if (this.isRefreshing) {
      promptAction.openToast({ message: '正在刷新中,请稍候' });
      return;
    }

    this.isRefreshing = true;
    console.log('手动刷新Token状态...');

    try {
      const response = await ApiService.validateToken();

      if (response.code === 200) {
        promptAction.openToast({ message: 'Token有效,连接正常' });
        this.lastCheckTime = this.formatTime(new Date());
        console.log('Token校验成功');
      } else {
        promptAction.openToast({ message: response.message || '校验失败' });
      }
    } catch (error) {
      const err = error as BusinessError;
      console.error('刷新Token状态失败:', JSON.stringify(err));

      // 401和409由HttpUtil的拦截器自动处理(清除状态+跳转登录页)
      // 这里只处理其他错误
      if (err.code !== 401 && err.code !== 409) {
        promptAction.openToast({ message: '网络请求失败,请检查连接' });
      }
    } finally {
      this.isRefreshing = false;
    }
  }

  // 更新时间
  private updateTime(): void {
    this.currentTime = this.formatTime(new Date());
  }

  // 格式化时间
  private formatTime(date: Date): string {
    const year = date.getFullYear();
    const month = (date.getMonth() + 1).toString().padStart(2, '0');
    const day = date.getDate().toString().padStart(2, '0');
    const hours = date.getHours().toString().padStart(2, '0');
    const minutes = date.getMinutes().toString().padStart(2, '0');
    const seconds = date.getSeconds().toString().padStart(2, '0');
    return `${year}-${month}-${day} ${hours}:${minutes}:${seconds}`;
  }

  // 手机号脱敏
  private maskPhone(phone: string): string {
    if (phone && phone.length === 11) {
      return phone.substring(0, 3) + '****' + phone.substring(7);
    }
    return phone || '未知';
  }

  // 退出登录
  private async logout(): Promise<void> {
    // 清除登录信息(包括持久化数据)
    await ConfigManager.clear();

    promptAction.openToast({ message: '已退出登录' });

    setTimeout(() => {
      this.navigateToLogin();
    }, 500);
  }

  // 跳转到登录页
  private navigateToLogin(): void {
    try {
      if (this.cachedUiContext !== null) {
        const router = this.cachedUiContext.getRouter();
        if (router && typeof router.replaceUrl === 'function') {
          router.replaceUrl({ url: 'pages/Index' });
          console.log("跳转到登录页成功");
        } else {
          throw new Error('Router.replaceUrl方法不存在或无效');
        }
      } else {
        throw new Error('UIContext为空');
      }
    } catch (err) {
      const error = err as BusinessError;
      console.error('跳转登录页失败:', error.message);

      try {
        if (this.cachedUiContext !== null) {
          const router = this.cachedUiContext.getRouter();
          if (router && typeof router.back === 'function') {
            router.back();
            console.log('使用back()返回成功');
          }
        }
      } catch (err2) {
        console.error('back()也失败:', err2);
        promptAction.openToast({ message: '返回失败,请手动操作' });
      }
    }
  }

  build() {
    Column({ space: 16 }) {
      // 登录成功
      Text('登录成功!')
        .fontSize(32)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333333')
        .margin({ top: 60, bottom: 20 })

      // 欢迎回来
      Text('欢迎回来')
        .fontSize(18)
        .fontColor('#666666')
        .margin({ bottom: 10 })

      // 用户名
      Text(this.username)
        .fontSize(28)
        .fontColor('#007DFF')
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: 15 })

      // 手机号(脱敏)
      Row() {
        Text('手机号: ')
          .fontSize(16)
          .fontColor('#999999')
        Text(this.maskPhone(this.phone))
          .fontSize(16)
          .fontColor('#666666')
      }
      .margin({ bottom: 10 })

      // 当前时间
      Row() {
        Text('当前时间: ')
          .fontSize(16)
          .fontColor('#999999')
        Text(this.currentTime)
          .fontSize(16)
          .fontColor('#666666')
      }
      .margin({ bottom: 10 })

      // 最后校验时间
      if (this.lastCheckTime) {
        Row() {
          Text('最后校验: ')
            .fontSize(14)
            .fontColor('#999999')
          Text(this.lastCheckTime)
            .fontSize(14)
            .fontColor('#52c41a')
        }
        .margin({ bottom: 30 })
      } else {
        Blank()
          .height(30)
      }

      // 刷新Token状态按钮
      Button() {
        if (this.isRefreshing) {
          Row({ space: 8 }) {
            LoadingProgress()
              .color('#007DFF')
              .width(20)
              .height(20)
            Text('校验中...')
              .fontSize(16)
              .fontColor('#007DFF')
          }
        } else {
          Text('刷新登录状态')
            .fontSize(16)
            .fontColor('#007DFF')
        }
      }
      .width('70%')
      .height(48)
      .backgroundColor('#E6F7FF')
      .borderRadius(24)
      .borderWidth(1)
      .borderColor('#91D5FF')
      .margin({ bottom: 16 })
      .enabled(!this.isRefreshing)
      .onClick(() => {
        this.refreshTokenStatus();
      })

      // 退出登录按钮
      Button('退出登录')
        .width('70%')
        .height(48)
        .fontSize(18)
        .fontColor('#FF4D4F')
        .backgroundColor('#FFF1F0')
        .borderRadius(24)
        .borderWidth(1)
        .borderColor('#FFCCC7')
        .onClick(() => {
          this.logout();
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Center)
  }
}