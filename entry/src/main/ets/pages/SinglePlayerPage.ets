import { networkManager, MessageData } from '../utils/NetworkManager';
import { gameManager, GamePlayer } from '../utils/GameManager';
import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { window } from '@kit.ArkUI';

@Entry
@Component
struct SinglePlayerPage {
  @State isLoading: boolean = false;
  @State isConnected: boolean = false;
  @State statusText: string = '';

  aboutToAppear() {
    // 设置横屏全屏
    window.getLastWindow(getContext(this)).then((win: window.Window) => {
      win.setWindowLayoutFullScreen(true);
      win.setWindowSystemBarEnable([]);
      win.setPreferredOrientation(window.Orientation.LANDSCAPE);
    }).catch((e: Error) => {
      console.error('set landscape fullscreen error:', JSON.stringify(e));
    });

    // 监听服务器游戏开始响应
    networkManager.on('SINGLE_PLAYER_GAME_START', (msg: MessageData) => {
      console.info('收到单人游戏开始:', JSON.stringify(msg));
      this.isLoading = false;

      // 初始化 GameManager
      gameManager.initServerSinglePlayerGame(msg);

      // 跳转游戏页面
      try {
        router.pushUrl({ url: 'pages/SinglePlayerGamePage' });
      } catch (e) {
        console.error('Router push error:', JSON.stringify(e));
      }
    });

    networkManager.on('ERROR', (msg: MessageData) => {
      console.error('服务器错误:', JSON.stringify(msg));
      this.isLoading = false;
      const message = msg.message ? String(msg.message) : '操作失败';
      try {
        promptAction.showToast({ message: message });
      } catch (e) {
        console.error('Show toast error:', JSON.stringify(e));
      }
    });
  }

  aboutToDisappear() {
    networkManager.clearHandlers();
  }

  build() {
    Stack() {
      // 背景装饰
      Row() {
        Text('🀄')
          .fontSize(150)
          .opacity(0.08)
          .rotate({ angle: -15 })
          .margin({ left: 80 })
        Blank()
        Text('🀅')
          .fontSize(120)
          .opacity(0.08)
          .rotate({ angle: 20 })
          .margin({ right: 100 })
      }
      .width('100%')
      .height('100%')

      // 主内容 - 横向布局
      Row() {
        // 左侧信息区域
        Column() {
          Text('🀄')
            .fontSize(100)
            .margin({ bottom: 20 })

          Text('单人麻将')
            .fontSize(32)
            .fontWeight(FontWeight.Bold)
            .fontColor('#fff')
            .letterSpacing(3)

          Text('SINGLE PLAYER')
            .fontSize(14)
            .fontColor('#FFD700')
            .letterSpacing(6)
            .margin({ top: 8 })

          Divider()
            .width(100)
            .color('rgba(255, 255, 255, 0.3)')
            .margin({ top: 25, bottom: 25 })

          Text('108张牌 · 无字牌')
            .fontSize(16)
            .fontColor('#ffffffcc')
            .margin({ bottom: 10 })

          Text('四人明牌对战')
            .fontSize(18)
            .fontColor('#ffffffcc')
            .margin({ bottom: 8 })

          Text('手动操控四家')
            .fontSize(14)
            .fontColor('#ffffff80')

          Blank()

          Text('需要连接服务器')
            .fontSize(13)
            .fontColor('#ffffff60')
        }
        .width('40%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .padding({ left: 40, right: 40 })

        // 右侧操作区域
        Column() {
          // 顶部导航
          Row() {
            Button('←')
              .fontSize(22)
              .width(50)
              .height(50)
              .backgroundColor('rgba(255, 255, 255, 0.15)')
              .fontColor('#fff')
              .borderRadius(25)
              .onClick(() => {
                if (this.isConnected) {
                  networkManager.disconnect();
                }
                try {
                  router.back();
                } catch (e) {
                  console.error('Router back error:', e);
                }
              })

            Blank()

            Text('开始游戏')
              .fontSize(22)
              .fontColor('#ffffffcc')
          }
          .width('100%')
          .padding({ left: 30, right: 30, top: 20 })

          Blank()

          // 开始游戏按钮
          Column() {
            Button(this.isLoading ? '正在连接...' : '开始游戏')
              .width(280)
              .height(65)
              .fontSize(22)
              .fontWeight(FontWeight.Medium)
              .backgroundColor(this.isLoading ? '#666' : '#4CAF50')
              .fontColor('#fff')
              .borderRadius(32)
              .enabled(!this.isLoading)
              .shadow({ radius: 15, color: '#4CAF5040', offsetX: 0, offsetY: 5 })
              .onClick(() => {
                this.startGame();
              })

            Button('返回大厅')
              .width(280)
              .height(55)
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .backgroundColor('rgba(255, 255, 255, 0.12)')
              .fontColor('#ffffffcc')
              .borderRadius(28)
              .margin({ top: 20 })
              .onClick(() => {
                if (this.isConnected) {
                  networkManager.disconnect();
                }
                try {
                  router.back();
                } catch (e) {
                  console.error('Router back error:', e);
                }
              })

            // 状态文字
            if (this.statusText) {
              Row() {
                LoadingProgress()
                  .width(20)
                  .height(20)
                  .color('#FF9800')
                  .margin({ right: 10 })
                Text(this.statusText)
                  .fontSize(15)
                  .fontColor('#FF9800')
              }
              .margin({ top: 25 })
            }
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)

          Blank()

          // 底部提示
          Text('所有手牌可见，自由操控四家出牌')
            .fontSize(13)
            .fontColor('#ffffff50')
            .margin({ bottom: 25 })
        }
        .width('60%')
        .height('100%')
        .justifyContent(FlexAlign.SpaceBetween)
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1a1a2e')
  }

  async startGame(): Promise<void> {
    this.isLoading = true;
    this.statusText = '正在连接服务器...';

    try {
      if (!networkManager.connectionStatus) {
        await networkManager.connect();
      }
      this.isConnected = true;
      this.statusText = '正在创建游戏...';

      // 发送单人游戏开始请求
      networkManager.send('SINGLE_PLAYER_START', { type: 'SINGLE_PLAYER_START' });
    } catch (error) {
      console.error('连接服务器失败:', error);
      this.isLoading = false;
      this.isConnected = false;
      this.statusText = '';
      try {
        promptAction.showToast({ message: '连接服务器失败，请检查网络' });
      } catch (e) {
        console.error('Show toast error:', e);
      }
    }
  }
}
