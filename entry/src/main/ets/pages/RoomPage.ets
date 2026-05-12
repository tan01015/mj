import { networkManager, MessageData, SendData } from '../utils/NetworkManager';
import { gameManager, GamePlayer, GameManagerState } from '../utils/GameManager';
import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';

@Entry
@Component
struct RoomPage {
  @State players: GamePlayer[] = [];
  @State isReady: boolean = false;
  @State allReady: boolean = false;
  @State isHost: boolean = false;
  private unsubscribe: () => void = () => {};

  aboutToAppear() {
    this.unsubscribe = gameManager.subscribe((state: GameManagerState) => {
      this.players = state.players;
      this.checkAllReady();
      this.checkIsHost();
    });

    networkManager.on('PLAYER_JOINED', (msg: MessageData) => {
      if (msg.players) {
        gameManager.updatePlayers(msg.players);
      }
    });

    networkManager.on('READY_UPDATE', (msg: MessageData) => {
      if (msg.players) {
        gameManager.updatePlayers(msg.players);
      }
    });

    networkManager.on('GAME_START', (msg: MessageData) => {
      gameManager.setGameStarted(true);
      try {
        promptAction.showToast({ message: '游戏开始！' });
      } catch (e) {
        console.error('Show toast error:', e);
      }
      try {
        router.pushUrl({ url: 'pages/GamePage' });
      } catch (e) {
        console.error('Router push error:', e);
      }
    });
  }

  aboutToDisappear() {
    this.unsubscribe();
  }

  build() {
    Row() {
      Column() {
        Button('←')
          .fontSize(24)
          .width(45)
          .height(45)
          .backgroundColor('rgba(255,255,255,0.2)')
          .fontColor('#fff')
          .margin({ bottom: 30 })
          .onClick(() => {
            networkManager.disconnect();
            gameManager.reset();
            try {
              router.back();
            } catch (e) {
              console.error('Router back error:', e);
            }
          })

        Button(this.isReady ? '取消准备' : '准备')
          .width('80%')
          .height(55)
          .fontSize(18)
          .backgroundColor(this.isReady ? '#FF9800' : '#4CAF50')
          .onClick(() => {
            this.toggleReady();
          })
          .margin({ bottom: 15 })

        if (this.canStartGame()) {
          Button('开始游戏')
            .width('80%')
            .height(55)
            .fontSize(18)
            .backgroundColor('#2196F3')
            .onClick(() => {
              this.startGame();
            })
        }
      }
      .width('20%')
      .height('100%')
      .padding({ top: 20, left: 20 })
      .backgroundColor('rgba(0,0,0,0.2)')

      Column() {
        Row() {
          Text('游戏房间')
            .fontSize(32)
            .fontWeight(FontWeight.Bold)
            .fontColor('#fff')
          
          Blank()

          Text(`房间ID: ${gameManager.gameState.roomId}`)
            .fontSize(16)
            .fontColor('#7f8c8d')
            .padding({ right: 20 })
        }
        .width('100%')
        .height(70)
        .padding({ top: 20 })
        .backgroundColor('rgba(0,0,0,0.3)')

        Row() {
          ForEach([0, 1, 2, 3], (seat: number) => {
            this.renderPlayerSeat(seat)
          }, (seat: number) => seat.toString())
        }
        .width('95%')
        .height('70%')
        .justifyContent(FlexAlign.SpaceEvenly)
        .alignItems(VerticalAlign.Center)
      }
      .width('80%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1a1a2e')
  }

  getPlayerColor(seat: number): string {
    const colors = ['#e74c3c', '#3498db', '#2ecc71', '#f39c12'];
    return colors[seat % colors.length];
  }

  toggleReady(): void {
    this.isReady = !this.isReady;
    const sendData: SendData = { type: 'READY', ready: this.isReady };
    networkManager.send('READY', sendData);
  }

  checkAllReady(): void {
    this.allReady = this.players.length > 0 && this.players.every((p: GamePlayer) => p.ready);
  }

  checkIsHost(): void {
    const state = gameManager.gameState;
    const hostPlayer = state.players.find((p: GamePlayer) => p.seat === 0);
    this.isHost = hostPlayer?.nickname === state.players[state.seat]?.nickname;
  }

  canStartGame(): boolean {
    const state = gameManager.gameState;
    return state.players.length >= 2 && this.allReady && this.isHost;
  }

  @Builder
  renderPlayerSeat(seat: number): void {
    Column() {
      if (this.players.find((p: GamePlayer) => p.seat === seat)) {
        Column() {
          Stack() {
            Circle()
              .width(70)
              .height(70)
              .fill(this.getPlayerColor(seat))
        
            Text(this.players.find((p: GamePlayer) => p.seat === seat)!.nickname.charAt(0).toUpperCase())
              .fontSize(28)
              .fontColor('#fff')
              .fontWeight(FontWeight.Bold)
          }
          .margin({ bottom: 10 })

          Text(this.players.find((p: GamePlayer) => p.seat === seat)!.nickname)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#fff')
            .maxLines(1)
            .width(100)
            .textAlign(TextAlign.Center)

          Text(this.players.find((p: GamePlayer) => p.seat === seat)!.ready ? '✓ 已准备' : '○ 未准备')
            .fontSize(13)
            .fontColor(this.players.find((p: GamePlayer) => p.seat === seat)!.ready ? '#4CAF50' : '#95a5a6')
            .margin({ top: 8 })
        }
      } else {
        Column() {
          Stack() {
            Circle()
              .width(70)
              .height(70)
              .fill('#ecf0f1')
        
            Text('?')
              .fontSize(28)
              .fontColor('#bdc3c7')
          }
          .margin({ bottom: 10 })

          Text('等待加入')
            .fontSize(14)
            .fontColor('#bdc3c7')
        }
      }
    }
    .width(120)
    .height(180)
    .justifyContent(FlexAlign.Center)
    .backgroundColor('rgba(255,255,255,0.1)')
    .borderRadius(12)
  }

  startGame(): void {
    networkManager.send('START_GAME', { type: 'START_GAME' });
  }
}
