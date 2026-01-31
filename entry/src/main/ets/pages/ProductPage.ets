import { ApiService, OrderModel, ProductModel, ConfigManager } from '../utils/HttpUtil';
import { promptAction, router } from '@kit.ArkUI';

// 定义接收参数的接口
interface RouterParams {
  id: number;
}

@Entry
@Component
struct ProductPage {
  @State product: ProductModel | null = null;
  @State buyCount: number = 1;
  @State isSubmitting: boolean = false;

  @State currentOrder: OrderModel | null = null;
  @State showPayDialog: boolean = false;
  @State isLoading: boolean = true; //

  private currentUserId: number = 0;
  private productId: number = 0;

  aboutToAppear() {
    //获取当前用户ID
    const userInfo = ConfigManager.getUserInfo();
    if (userInfo) {
      this.currentUserId = userInfo.userId;
    } else {
      // 如果没登录，不要直接 back，防止路由错乱，给个默认值测试
      this.currentUserId = 1;
    }

    //获取路由参数中的商品ID
    const params = router.getParams() as RouterParams;
    if (params && params.id) {
      this.productId = params.id;
      console.log('获取到商品ID:', this.productId);
    } else {
      // 如果直接打开详情页没有参数，可以给个默认值测试，或者提示错误
      this.productId = 1;
      console.log('未获取到商品ID，使用默认ID: 1');
    }
    this.loadProductData();
  }

  async loadProductData() {
    this.isLoading = true;
    try {
      const res = await ApiService.getProduct(this.productId);
      if (res.code === 200 && res.data) {
        this.product = res.data;
        if (this.buyCount > this.product.availableStock && this.product.availableStock > 0) {
          this.buyCount = this.product.availableStock;
        }
      }
    } catch (err) {
      console.error('加载商品失败', err);
      promptAction.showToast({ message: '加载失败' });
    } finally {
      this.isLoading = false;
    }
  }

  build() {
    //使用 Stack 布局作为根节点，方便处理弹窗和 Loading
    Stack({ alignContent: Alignment.TopStart }) {

      //主体内容
      Column() {
        //顶部标题栏
        Row() {
          Text('< 返回')
            .fontSize(16)
            .padding(10)
            .onClick(() => router.back())
          Text('商品详情')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .margin({ left: 20 })
        }
        .width('100%')
        .height(50)
        .backgroundColor('#FFF')
        .border({ width: { bottom: 1 }, color: '#F1F1F1' })

        //内容区域，使用 List 替代 Scroll
        if (this.isLoading) {
          Column() {
            LoadingProgress().width(50).height(50)
            Text('加载商品中...').fontSize(14).fontColor('#999').margin({ top: 10 })
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .layoutWeight(1)
        } else if (this.product) {
          List() {
            ListItem() {
              Column({ space: 15 }) {
                //用一个灰色方块代替图片
                Row().width('100%').height(200).backgroundColor('#F5F5F5')

                // 价格与库存
                Row() {
                  Text(`￥${this.product?.price}`) // 暂时去掉 toFixed 防止空指针
                    .fontSize(20)
                    .fontColor('#FF0033')
                    .fontWeight(FontWeight.Bold)

                  Blank()

                  Text(`剩余: ${this.product?.availableStock}`)
                    .fontSize(14)
                    .fontColor('#666')
                }
                .width('100%')

                Text(this.product?.name || '未知商品')
                  .fontSize(24)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#333')

                Text('商品描述：xxxxxxx')
                  .fontSize(14)
                  .fontColor('#666')
                  .lineHeight(20)
              }
              .padding(20)
            }
          }
          .width('100%')
          .layoutWeight(1) // 占满中间

          //底部栏
          this.BottomBar()
        } else {
          //加载失败显示
          Column() {
            Text('商品加载失败').margin({ top: 50 })
            Button('重试').onClick(() => this.loadProductData()).margin({ top: 10 })
          }.width('100%').layoutWeight(1).alignItems(HorizontalAlign.Center)
        }
      }
      .width('100%')
      .height('100%')

      //支付弹窗，在最上层
      if (this.showPayDialog && this.currentOrder) {
        this.PayDialog()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFF')
  }

  @Builder BottomBar() {
    Column() {
      // 数量选择
      Row() {
        Text('购买数量').fontSize(16).fontWeight(FontWeight.Bold)
        Blank()
        Button('-').width(32).height(32).backgroundColor('#F5F5F5').fontColor('#333')
          .onClick(() => {
            if (this.buyCount > 1) this.buyCount--;
            else promptAction.showToast({ message: '不能小于1' });
          })
        Text(this.buyCount.toString()).width(50).textAlign(TextAlign.Center).fontSize(16)
        Button('+').width(32).height(32).backgroundColor('#F5F5F5').fontColor('#333')
          .onClick(() => {
            if (this.product && this.buyCount < this.product.availableStock) this.buyCount++;
            else promptAction.showToast({ message: '不能超过最大库存' });
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 10, bottom: 10 })
      .backgroundColor('#FAFAFA')

      // 按钮
      Row() {
        Button(this.product?.availableStock === 0 ? '已售罄' : (this.isSubmitting ? '抢购中...' : '立即抢购'))
          .width('90%')
          .height(44)
          .backgroundColor(this.product?.availableStock === 0 ? '#CCCCCC' : '#FF0033')
          .enabled(this.product?.availableStock !== 0 && !this.isSubmitting)
          .onClick(() => this.handleBuy())
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ bottom: 10 })
      .backgroundColor(Color.White)
    }
    .border({ width: { top: 1 }, color: '#EEE' })
  }

  @Builder PayDialog() {
    Stack() {
      Rect().width('100%').height('100%').fill('rgba(0,0,0,0.5)')
        .onClick(() => this.cancelPayment())

      Column({ space: 15 }) {
        Text('收银台').fontSize(18).fontWeight(FontWeight.Bold)
        Divider()

        Row() {
          Text('订单号').fontColor('#666')
          Blank()
          Text(this.currentOrder?.orderNo).fontColor('#333')
        }.width('100%')

        Text(`￥${this.currentOrder?.amount}`)
          .fontSize(32).fontColor('#FF0033').fontWeight(FontWeight.Bold)

        Button('确认支付')
          .width('100%')
          .backgroundColor('#007DFF')
          .onClick(() => this.handlePay())

        Button('取消支付')
          .width('100%')
          .backgroundColor('#F5F5F5')
          .fontColor('#666')
          .onClick(() => this.cancelPayment())
      }
      .width('85%')
      .backgroundColor(Color.White)
      .borderRadius(16)
      .padding(25)
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Center) // 居中
  }

  async cancelPayment() {
    if (this.currentOrder) {
      try {
        await ApiService.cancelOrder(this.currentOrder.orderNo);
        promptAction.showToast({ message: '订单已取消' });
      } catch (err) {
        console.error('取消失败', err);
      }
    }
    this.showPayDialog = false;
    this.currentOrder = null;
    this.loadProductData();
  }

  async handleBuy() {
    if (!this.product) return;
    this.isSubmitting = true;
    try {
      const res = await ApiService.createOrder(this.currentUserId, this.productId, this.buyCount);
      if (res.code === 200 && res.data) {
        promptAction.showToast({ message: '抢购成功！' });
        this.currentOrder = res.data;
        this.showPayDialog = true;
      } else {
        promptAction.showToast({ message: res.message || '抢购失败' });
        this.loadProductData();
      }
    } catch (err) {
      promptAction.showToast({ message: '网络异常' });
    } finally {
      this.isSubmitting = false;
    }
  }

  async handlePay() {
    if (!this.currentOrder) return;
    try {
      const res = await ApiService.payOrder(this.currentOrder.orderNo);
      if (res.code === 200) {
        promptAction.showToast({ message: '支付成功！' });
        this.showPayDialog = false;
        this.currentOrder = null;
        this.loadProductData();
      } else {
        promptAction.showToast({ message: res.message });
      }
    } catch (err) {
      promptAction.showToast({ message: '支付失败' });
    }
  }
}