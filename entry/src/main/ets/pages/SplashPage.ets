import router from '@ohos.router';
import { window } from '@kit.ArkUI';

@Entry
@Component
struct SplashPage {
  @State showButton: boolean = false;

  aboutToAppear() {
    // 设置横屏全屏
    window.getLastWindow(getContext(this)).then((win: window.Window) => {
      win.setWindowLayoutFullScreen(true);
      win.setWindowSystemBarEnable([]);
      win.setPreferredOrientation(window.Orientation.LANDSCAPE);
    }).catch((e: Error) => {
      console.error('set landscape fullscreen error:', JSON.stringify(e));
    });

    setTimeout(() => {
      this.showButton = true;
    }, 1500);
  }

  build() {
    Stack() {
      // 背景装饰
      Column() {
        // 左侧装饰
        Row() {
          Column() {
            Text('🀄')
              .fontSize(80)
              .opacity(0.3)
            Text('🀅')
              .fontSize(60)
              .opacity(0.2)
              .margin({ top: 20 })
          }
          .margin({ left: 40 })

          Blank()

          // 右侧装饰
          Column() {
            Text('🀆')
              .fontSize(60)
              .opacity(0.2)
            Text('🀇')
              .fontSize(80)
              .opacity(0.3)
              .margin({ top: 20 })
          }
          .margin({ right: 40 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .height('100%')

      // 主内容 - 横向布局
      Row() {
        // 左侧Logo区域
        Column() {
          Text('🎮')
            .fontSize(100)
            .margin({ bottom: 20 })

          Text('麻将工作室')
            .fontSize(48)
            .fontWeight(FontWeight.Bold)
            .fontColor('#fff')
            .letterSpacing(4)

          Text('MAHJONG STUDIO')
            .fontSize(18)
            .fontColor('#FFD700')
            .letterSpacing(8)
            .margin({ top: 10 })
        }
        .width('50%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)

        // 右侧操作区域
        Column() {
          if (this.showButton) {
            Button('开始游戏')
              .width(280)
              .height(70)
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .backgroundColor('#FFD700')
              .fontColor('#1a1a1a')
              .borderRadius(35)
              .shadow({
                radius: 20,
                color: 'rgba(255, 215, 0, 0.5)',
                offsetX: 0,
                offsetY: 5
              })
              .onClick(() => {
                this.startGame();
              })

            Text('点击进入游戏大厅')
              .fontSize(14)
              .fontColor('#ffffff80')
              .margin({ top: 20 })
          } else {
            // 加载动画
            LoadingProgress()
              .width(60)
              .height(60)
              .color('#FFD700')
          }
        }
        .width('50%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .height('100%')

      // 版本号
      Text('v1.0.0')
        .fontSize(14)
        .fontColor('#ffffff60')
        .position({ right: 40, bottom: 30 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1a1a2e')
  }

  startGame() {
    router.pushUrl({ url: 'pages/MainMenuPage' });
  }
}
