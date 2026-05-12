import { networkManager, MessageData, SendData } from '../utils/NetworkManager';
import { gameManager, GamePlayer, GameManagerState } from '../utils/GameManager';
import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';

@Entry
@Component
struct GameRoomPage {
  @State players: GamePlayer[] = [];
  @State isReady: boolean = false;
  @State allReady: boolean = false;
  @State isHost: boolean = false;
  @State mode: string = 'single';
  @State gameStarted: boolean = false;
  private unsubscribe: () => void = () => {};

  aboutToAppear() {
    const params = router.getParams() as Record<string, string>;
    this.mode = params.mode || 'single';

    this.unsubscribe = gameManager.subscribe((state: GameManagerState) => {
      this.players = state.players;
      this.checkAllReady();
      this.checkIsHost();
    });

    if (this.mode === 'single') {
      this.startSinglePlayerGame();
    } else {
      this.setupMultiplayerListeners();
    }
  }

  aboutToDisappear() {
    this.unsubscribe();
  }

  build() {
    Row() {
      if (this.mode === 'multiplayer') {
        Column() {
          Stack() {
            Button('←')
              .fontSize(24)
              .width(45)
              .height(45)
              .backgroundColor('rgba(255,255,255,0.2)')
              .fontColor('#fff')
              .onClick(() => {
                this.leaveRoom();
              })
          }
          .width('100%')
          .padding({ top: 20, left: 20 })

          Blank()

          Column() {
            Button(this.isReady ? '取消准备' : '准备就绪')
              .width('80%')
              .height(55)
              .fontSize(20)
              .fontWeight(FontWeight.Medium)
              .backgroundColor(this.isReady ? '#FF9800' : '#4CAF50')
              .fontColor('#ffffff')
              .borderRadius(8)
              .onClick(() => {
                this.toggleReady();
              })

            if (this.canStartGame()) {
              Button('开始游戏')
                .width('80%')
                .height(55)
                .fontSize(20)
                .fontWeight(FontWeight.Medium)
                .backgroundColor('#2196F3')
                .fontColor('#ffffff')
                .borderRadius(8)
                .margin({ top: 12 })
                .onClick(() => {
                  this.startGame();
                })
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .padding({ bottom: 30 })
        }
        .width('20%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.2)')
      }

      Column() {
        Row() {
          Blank()

          Text(this.mode === 'single' ? '单人对战' : '局域网对战')
            .fontSize(32)
            .fontWeight(FontWeight.Bold)
            .fontColor('#fff')
          
          Blank()

          if (this.mode === 'multiplayer') {
            Text(`房间ID: ${gameManager.gameState.roomId}`)
              .fontSize(14)
              .fontColor('#7f8c8d')
              .padding({ right: 20 })
          }
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

        if (this.mode === 'single') {
          Column() {
            Text('🤖')
              .fontSize(60)
              .margin({ bottom: 15 })

            Text('准备开始')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor('#fff')
              .margin({ bottom: 8 })

            Text('即将与AI对手进行对战')
              .fontSize(15)
              .fontColor('#ffffffcc')
              .margin({ bottom: 30 })

            if (!this.gameStarted) {
              LoadingProgress()
                .width(60)
                .height(60)
                .color('#4CAF50')
            } else {
              Text('游戏加载中...')
                .fontSize(15)
                .fontColor('#4CAF50')
            }
          }
          .width('100%')
          .height('70%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        }
      }
      .width(this.mode === 'multiplayer' ? '80%' : '100%')
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

  startSinglePlayerGame(): void {
    gameManager.setRoomInfo('single-player', 'player-' + Date.now(), 0);
    
    const aiPlayers: GamePlayer[] = [
      { seat: 0, nickname: '玩家', ready: true, online: true },
      { seat: 1, nickname: 'AI-简单', ready: true, online: true },
      { seat: 2, nickname: 'AI-中等', ready: true, online: true },
      { seat: 3, nickname: 'AI-困难', ready: true, online: true }
    ];
    
    gameManager.updatePlayers(aiPlayers);
    gameManager.setGameStarted(true);

    setTimeout(() => {
      this.gameStarted = true;
      
      networkManager.on('GAME_START', (msg: MessageData) => {
        console.info('Single player game starting:', msg);
        
        if (msg.hands) {
          const hands = msg.hands as Record<string, Array<number>>;
          const mySeat = gameManager.gameState.seat;
          const myHand = hands[String(mySeat)];
          if (myHand) {
            console.info('Received hand:', myHand);
            gameManager.updateMyHand(myHand);
          }
        }
        
        setTimeout(() => {
          try {
            router.replaceUrl({ url: 'pages/GamePage' });
          } catch (e) {
            console.error('Router replace error:', e);
          }
        }, 500);
      });
      
      networkManager.connect().then(() => {
        networkManager.send('CREATE_ROOM', {
          type: 'CREATE_ROOM',
          playerName: '玩家',
          gameMode: 'single',
          maxPlayers: 4
        });
        
        setTimeout(() => {
          networkManager.send('START_GAME', { type: 'START_GAME' });
        }, 500);
      }).catch((err: Error) => {
        console.error('Connect error:', err);
      });
    }, 500);
  }

  setupMultiplayerListeners(): void {
    networkManager.on('PLAYER_JOINED', (msg: MessageData) => {
      if (msg.players) {
        gameManager.updatePlayers(msg.players);
        try {
          promptAction.showToast({ message: '新玩家加入' });
        } catch (e) {
          console.error('Show toast error:', e);
        }
      }
    });

    networkManager.on('PLAYER_LEFT', (msg: MessageData) => {
      try {
        promptAction.showToast({ message: '有玩家离开' });
      } catch (e) {
        console.error('Show toast error:', e);
      }
    });

    networkManager.on('READY_UPDATE', (msg: MessageData) => {
      if (msg.players) {
        gameManager.updatePlayers(msg.players);
      }
    });

    networkManager.on('GAME_START', (msg: MessageData) => {
      console.info('Game starting:', msg);
      gameManager.setGameStarted(true);
      
      if (msg.hands) {
        const hands = msg.hands as Record<string, Array<number>>;
        const mySeat = gameManager.gameState.seat;
        const myHand = hands[String(mySeat)];
        if (myHand) {
          gameManager.updateMyHand(myHand);
        }
      }
      
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

    networkManager.on('ERROR', (msg: MessageData) => {
      const message = msg.message ? String(msg.message) : '操作失败';
      try {
        promptAction.showToast({ message: message });
      } catch (e) {
        console.error('Show toast error:', e);
      }
    });
  }

  toggleReady(): void {
    this.isReady = !this.isReady;
    const sendData: SendData = { type: 'READY', ready: this.isReady };
    networkManager.send('READY', sendData);
  }

  checkAllReady(): void {
    if (this.players.length >= 2) {
      this.allReady = this.players.every((p: GamePlayer) => p.ready);
    } else {
      this.allReady = false;
    }
  }

  checkIsHost(): void {
    const state = gameManager.gameState;
    const hostPlayer = state.players.find((p: GamePlayer) => p.seat === 0);
    this.isHost = hostPlayer?.nickname === gameManager.gameState.players[state.seat]?.nickname;
  }

  canStartGame(): boolean {
    const state = gameManager.gameState;
    return state.players.length >= 2 && 
           this.allReady && 
           this.isHost;
  }

  startGame(): void {
    networkManager.send('START_GAME', { type: 'START_GAME' });
  }

  leaveRoom(): void {
    networkManager.disconnect();
    gameManager.reset();
    try {
      router.back();
    } catch (e) {
      console.error('Router back error:', e);
    }
  }
}
