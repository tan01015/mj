import router from '@ohos.router';

@Entry
@Component
struct SplashPage {
  @State showButton: boolean = false;

  aboutToAppear() {
    setTimeout(() => {
      this.showButton = true;
    }, 1500);
  }

  build() {
    Row() {
      Column() {
        Text('🎮')
          .fontSize(100)
          .margin({ bottom: 20 })

        Text('麻将工作室')
          .fontSize(40)
          .fontWeight(FontWeight.Bold)
          .fontColor('#fff')
          .letterSpacing(4)

        Text('MAHJONG STUDIO')
          .fontSize(16)
          .fontColor('#FFD700')
          .letterSpacing(8)
          .margin({ top: 10 })

        if (this.showButton) {
          Button('开始游戏')
            .width(220)
            .height(55)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .backgroundColor('#FFD700')
            .fontColor('#1a1a1a')
            .borderRadius(28)
            .margin({ top: 60 })
            .onClick(() => {
              this.startGame();
            })
        }
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      Text('v1.0.0')
        .fontSize(12)
        .fontColor('#ffffff80')
        .position({ right: 30, bottom: 30 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1a1a2e')
  }

  startGame() {
    router.pushUrl({ url: 'pages/MainMenuPage' });
  }
}
