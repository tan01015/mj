import { networkManager, MessageData, SendData } from '../utils/NetworkManager';
import { gameManager, GamePlayer, GameManagerState } from '../utils/GameManager';
import { MahjongRules, MahjongTile } from '../engine/MahjongRules';
import { MahjongGame, GameState as LocalGameState } from '../engine/MahjongGame';
import { AdvancedAI, AIDifficulty, AIDecision } from '../ai/AdvancedAI';
import { statisticsManager } from '../utils/StatisticsManager';
import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { window } from '@kit.ArkUI';

@Entry
@Component
struct GamePage {
  @State gameState: GameManagerState = gameManager.gameState;
  @State showOperationPanel: boolean = false;
  @State availableActions: string[] = [];
  @State lastDiscardedTile: number = 0;
  @State selectedTile: number = 0;
  @State showTileInfo: boolean = false;
  @State currentTileInfo: MahjongTile | null = null;
  @State gameMessage: string = '';
  @State showGameOver: boolean = false;
  @State gameOverWinner: string = '';
  @State gameOverScores: Record<string, number> = {};
  @State showAnimation: boolean = false;
  @State animationText: string = '';
  @State animationColor: string = '#4CAF50';
  @State actionNotification: string = '';

  private unsubscribe: () => void = () => {};
  private aiPlayers: Map<number, AdvancedAI> = new Map();
  private gameStartTime: number = 0;

  aboutToAppear() {
    // 设置横屏全屏
    window.getLastWindow(getContext(this)).then((win: window.Window) => {
      win.setWindowLayoutFullScreen(true);
      win.setWindowSystemBarEnable([]);
      win.setPreferredOrientation(window.Orientation.LANDSCAPE);
    }).catch((e: Error) => {
      console.error('set landscape fullscreen error:', JSON.stringify(e));
    });

    // 检查是否为单机模式
    const params = router.getParams() as Record<string, string>;
    const isSinglePlayer = params ? params['isSinglePlayer'] === 'true' : false;

    gameManager.setSinglePlayerMode(isSinglePlayer);

    if (isSinglePlayer) {
      // 单机模式：初始化本地游戏引擎
      gameManager.initSinglePlayerGame();
      this.lastDiscardedTile = 0;
      this.gameStartTime = Date.now();
      this.initializeAIPlayers();
    } else {
      // 多人模式：游戏数据已由 RoomPage 存入 GameManager，直接开始
      this.gameStartTime = Date.now();
      this.lastDiscardedTile = 0;
      this.setupNetworkListeners();
    }

    this.unsubscribe = gameManager.subscribe((state: GameManagerState) => {
      this.gameState = state;
      this.updateGameStatus();
    });

    this.updateGameStatus();
  }

  aboutToDisappear() {
    this.unsubscribe();
    if (!this.gameState.isSinglePlayer) {
      networkManager.clearHandlers();
    }
  }

  build() {
    Stack() {
      Row() {
        // 左侧玩家信息面板
        Column() {
          this.buildPlayerPanel()
        }
        .width('20%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.2)')
        .padding(15)

        // 中间游戏区域
        Column() {
          this.buildGameArea()
        }
        .width('60%')
        .height('100%')
        .backgroundColor('#1a1a2e')

        // 右侧操作面板
        Column() {
          this.buildControlPanel()
        }
        .width('20%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.2)')
        .padding(15)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#1a1a2e')

      // 底部白色区域遮罩
      Column()
        .width('100%')
        .height(50)
        .backgroundColor('#1a1a2e')
        .align(Alignment.Bottom)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])

      // 动画效果层
      if (this.showAnimation) {
        Column() {
          Text(this.animationText)
            .fontSize(48)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.animationColor)
            .shadow({ radius: 10, color: '#000' })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor('rgba(0,0,0,0.3)')
        .onClick(() => {
          this.showAnimation = false;
        })
      }

      // 游戏结束弹窗
      if (this.showGameOver) {
        Column() {
          Text('🎉 游戏结束 🎉')
            .fontSize(32)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFD700')
            .margin({ bottom: 20 })

          Text(`获胜者: ${this.gameOverWinner}`)
            .fontSize(24)
            .fontColor('#fff')
            .margin({ bottom: 20 })

          Column() {
            Text('最终得分')
              .fontSize(18)
              .fontColor('#ffffffcc')
              .margin({ bottom: 10 })

            ForEach(Object.entries(this.gameOverScores), (entry: [string, number]) => {
              Row() {
                Text(entry[0])
                  .fontSize(16)
                  .fontColor('#fff')
                  .width(100)
                Text(`${entry[1] > 0 ? '+' : ''}${entry[1]}`)
                  .fontSize(16)
                  .fontColor(entry[1] > 0 ? '#4CAF50' : '#f44336')
                  .fontWeight(FontWeight.Bold)
              }
              .width('80%')
              .justifyContent(FlexAlign.SpaceBetween)
              .padding(8)
              .margin({ bottom: 5 })
            }, (entry: [string, number]) => entry[0])
          }
          .width('90%')
          .padding(15)
          .backgroundColor('rgba(255,255,255,0.1)')
          .borderRadius(10)
          .margin({ bottom: 20 })

          Button('返回大厅')
            .width('60%')
            .height(50)
            .fontSize(18)
            .backgroundColor('#4CAF50')
            .fontColor('#fff')
            .borderRadius(25)
            .onClick(() => {
              this.returnToLobby();
            })
        }
        .width('80%')
        .padding(30)
        .backgroundColor('rgba(26,26,46,0.95)')
        .borderRadius(20)
        .border({ width: 2, color: '#FFD700' })
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  buildPlayerPanel(): void {
    Column() {
      Text('玩家信息')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#fff')
        .margin({ bottom: 20 })

      ForEach(this.gameState.players, (player: GamePlayer) => {
        Row() {
          Circle()
            .width(40)
            .height(40)
            .fill(this.getPlayerColor(player.seat))
          
          Column() {
            Text(player.nickname)
              .fontSize(16)
              .fontColor('#fff')
              .maxLines(1)
            
            Text(`分数: ${player.score || 0}`)
              .fontSize(12)
              .fontColor('#ffffffcc')
          }
          .margin({ left: 10 })
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          if (player.seat === this.gameState.currentPlayer) {
            Text('🔄')
              .fontSize(16)
          }
        }
        .width('100%')
        .padding(10)
        .backgroundColor('rgba(255,255,255,0.1)')
        .borderRadius(8)
        .margin({ bottom: 8 })
      }, (player: GamePlayer) => player.seat.toString())

      Blank()

      Column() {
        Text(`剩余牌数: ${this.gameState.remainingTiles}`)
          .fontSize(14)
          .fontColor('#ffffffcc')
        
        Text(`庄家: ${this.getPlayerName(this.gameState.dealer)}`)
          .fontSize(14)
          .fontColor('#ffffffcc')
          .margin({ top: 5 })
        
        Text(`回合: ${this.gameState.round}`)
          .fontSize(14)
          .fontColor('#ffffffcc')
          .margin({ top: 5 })
      }
      .width('100%')
      .padding(10)
      .backgroundColor('rgba(255,255,255,0.05)')
      .borderRadius(8)
    }
  }

  @Builder
  buildGameArea(): void {
    Column() {
      // 顶部对手区域
      Row() {
        ForEach([1, 2, 3], (seat: number) => {
          if (seat !== this.gameState.seat) {
            this.buildOpponentArea(seat)
          }
        }, (seat: number) => seat.toString())
      }
      .width('100%')
      .height('25%')
      .justifyContent(FlexAlign.SpaceAround)

      // 中间弃牌区域 - 显示所有玩家的弃牌
      Column() {
        Text('弃牌区')
          .fontSize(16)
          .fontColor('#ffffffcc')
          .margin({ bottom: 10 })
        
        // 显示4个玩家的弃牌
        Row() {
          // 玩家0（自己）的弃牌
          Column() {
            Text('我')
              .fontSize(12)
              .fontColor('#ffffffcc')
              .margin({ bottom: 5 })
            Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
              ForEach(this.gameState.myDiscarded, (tile: number) => {
                this.buildDiscardTile(tile)
              }, (tile: number) => 'my-' + tile.toString())
            }
            .width(100)
            .height(50)
          }
          .margin({ right: 10 })

          // 玩家1的弃牌
          Column() {
            Text(this.getPlayerName(1))
              .fontSize(12)
              .fontColor('#ffffffcc')
              .margin({ bottom: 5 })
            Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
              ForEach(this.getDiscardedTiles(1), (tile: number) => {
                this.buildDiscardTile(tile)
              }, (tile: number) => 'p1-' + tile.toString())
            }
            .width(100)
            .height(50)
          }
          .margin({ right: 10 })

          // 玩家2的弃牌
          Column() {
            Text(this.getPlayerName(2))
              .fontSize(12)
              .fontColor('#ffffffcc')
              .margin({ bottom: 5 })
            Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
              ForEach(this.getDiscardedTiles(2), (tile: number) => {
                this.buildDiscardTile(tile)
              }, (tile: number) => 'p2-' + tile.toString())
            }
            .width(100)
            .height(50)
          }
          .margin({ right: 10 })

          // 玩家3的弃牌
          Column() {
            Text(this.getPlayerName(3))
              .fontSize(12)
              .fontColor('#ffffffcc')
              .margin({ bottom: 5 })
            Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
              ForEach(this.getDiscardedTiles(3), (tile: number) => {
                this.buildDiscardTile(tile)
              }, (tile: number) => 'p3-' + tile.toString())
            }
            .width(100)
            .height(50)
          }
        }
        .width('90%')
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .height('20%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      // 底部玩家手牌区域
      Column() {
        Text('我的手牌')
          .fontSize(16)
          .fontColor('#ffffffcc')
          .margin({ bottom: 10 })
        
        Scroll() {
          Row() {
            ForEach(this.gameState.myHand, (tile: number, index: number) => {
              this.buildTile(tile, true)
            }, (tile: number, index: number) => `${tile}-${index}`)
          }
          .justifyContent(FlexAlign.Center)
        }
        .scrollable(ScrollDirection.Horizontal)
        .width('90%')
        .height(120)
      }
      .width('100%')
      .height('35%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      // 最近动态（碰/杠/胡提示 - 持久显示）
      if (this.actionNotification) {
        Row() {
          Text(this.actionNotification)
            .fontSize(18)
            .fontColor('#FFD700')
            .fontWeight(FontWeight.Bold)
        }
        .margin({ top: 8 })
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .backgroundColor('rgba(255,215,0,0.15)')
        .borderRadius(8)
        .border({ width: 1, color: 'rgba(255,215,0,0.3)' })
      }

      // 游戏消息
      if (this.gameMessage) {
        Text(this.gameMessage)
          .fontSize(18)
          .fontColor('#4CAF50')
          .margin({ top: 20 })
          .textAlign(TextAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .padding(20)
  }

  @Builder
  buildDiscardTile(tile: number): void {
    Stack() {
      Rect()
        .width(30)
        .height(45)
        .fill(gameManager.getTileColor(tile))
        .borderRadius(4)
      
      Column() {
        Text(gameManager.getTileDisplayText(tile))
          .fontSize(12)
          .fontColor('#fff')
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
    .margin(1)
  }

  @Builder
  buildOpponentArea(seat: number): void {
    Column() {
      Text(this.getPlayerName(seat))
        .fontSize(16)
        .fontColor('#fff')
        .margin({ bottom: 5 })

      Text(`手牌: ${this.getOpponentHandCount(seat)}张`)
        .fontSize(12)
        .fontColor('#ffffffcc')

      // 显示对手的牌组（碰/杠/吃）
      if (this.getOpponentMelds(seat).length > 0) {
        Row() {
          ForEach(this.getOpponentMelds(seat), (meld: number[]) => {
            Text(`${gameManager.getTileDisplayText(meld[0])}`)
              .fontSize(8)
              .fontColor('#FFD700')
              .margin({ left: 2 })
          }, (meld: number[], index: number) => `${seat}-meld-${index}`)
        }
        .margin({ top: 3 })
      }

      if (seat === this.gameState.currentPlayer) {
        Text('思考中...')
          .fontSize(12)
          .fontColor('#FF9800')
          .margin({ top: 5 })
      }
    }
    .width(100)
    .height(80)
    .backgroundColor('rgba(255,255,255,0.1)')
    .borderRadius(8)
    .padding(10)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  buildTile(tile: number, selectable: boolean): void {
    Stack() {
      Rect()
        .width(40)
        .height(60)
        .fill(gameManager.getTileColor(tile))
        .borderRadius(4)
      
      Column() {
        Text(gameManager.getTileDisplayText(tile))
          .fontSize(14)
          .fontColor('#fff')
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
    .margin(2)
    .onClick(() => {
      if (selectable && gameManager.isMyTurn()) {
        this.selectTile(tile);
      }
    })
  }

  @Builder
  buildControlPanel(): void {
    Column() {
      Text('游戏控制')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#fff')
        .margin({ bottom: 20 })

      if (gameManager.isMyTurn()) {
        // 判断是摸牌阶段还是出牌阶段
        if (this.needDiscard()) {
          Text('请选择要打出的牌')
            .fontSize(15)
            .fontColor('#FFD700')
            .margin({ bottom: 10 })
        } else {
          Button('摸牌')
            .width('100%')
            .height(45)
            .fontSize(16)
            .backgroundColor('#4CAF50')
            .fontColor('#ffffff')
            .borderRadius(8)
            .onClick(() => {
              this.drawTile();
            })
            .margin({ bottom: 10 })
        }

        if (this.selectedTile && this.needDiscard()) {
          Button(`打出 ${gameManager.getTileDisplayText(this.selectedTile)}`)
            .width('100%')
            .height(45)
            .fontSize(16)
            .backgroundColor('#2196F3')
            .fontColor('#ffffff')
            .borderRadius(8)
            .onClick(() => {
              this.discardTile();
            })
            .margin({ bottom: 10 })
        }
      }

      if (this.showOperationPanel) {
        Column() {
          Text('可选操作')
            .fontSize(16)
            .fontColor('#fff')
            .margin({ bottom: 10 })

          ForEach(this.availableActions, (action: string) => {
            Button(this.getActionText(action))
              .width('100%')
              .height(40)
              .fontSize(14)
              .backgroundColor(this.getActionColor(action))
              .fontColor('#ffffff')
              .borderRadius(6)
              .onClick(() => {
                this.performAction(action);
              })
              .margin({ bottom: 8 })
          }, (action: string) => action)

          Button('过 (PASS)')
            .width('100%')
            .height(40)
            .fontSize(14)
            .backgroundColor('#666666')
            .fontColor('#ffffff')
            .borderRadius(6)
            .onClick(() => {
              this.passReaction();
            })
        }
        .width('100%')
        .padding(10)
        .backgroundColor('rgba(255,255,255,0.1)')
        .borderRadius(8)
        .margin({ bottom: 10 })
      }

      Blank()

      Button('返回大厅')
        .width('100%')
        .height(45)
        .fontSize(16)
        .backgroundColor('#FF5722')
        .fontColor('#ffffff')
        .borderRadius(8)
        .onClick(() => {
          this.returnToLobby();
        })
        .margin({ bottom: 10 })

      Button('游戏规则')
        .width('100%')
        .height(45)
        .fontSize(16)
        .backgroundColor('#9C27B0')
        .borderRadius(8)
        .onClick(() => {
          this.showGameRules();
        })
    }
  }

  // 初始化AI玩家
  private initializeAIPlayers(): void {
    const aiSeats = [1, 2, 3]; // AI玩家座位号
    aiSeats.forEach(seat => {
      let difficulty: AIDifficulty;
      if (seat === 1) {
        difficulty = AIDifficulty.EASY;
      } else if (seat === 2) {
        difficulty = AIDifficulty.MEDIUM;
      } else {
        difficulty = AIDifficulty.HARD;
      }
      this.aiPlayers.set(seat, new AdvancedAI(difficulty, seat));
    });
  }

  // 设置网络监听器
  private setupNetworkListeners(): void {
    networkManager.on('GAME_START', (msg: MessageData) => {
      console.info('GamePage received GAME_START:', JSON.stringify(msg));
      gameManager.setGameStarted(true);
      this.gameStartTime = Date.now();

      // 手牌现在是seat索引的Map（服务端已转换）
      if (msg.hands) {
        const hands = msg.hands as Record<string, Array<number>>;
        const mySeat = gameManager.gameState.seat;
        const myHand = hands[String(mySeat)];
        if (myHand) {
          console.info('我的手牌:', JSON.stringify(myHand));
          gameManager.updateMyHand(myHand);
        }
        // 同步其他玩家手牌数量
        gameManager.syncMultiplayerHands(hands);
      }

      if (msg.currentPlayer !== undefined) {
        gameManager.updateCurrentPlayer(Number(msg.currentPlayer));
      }

      if (msg.remainingTiles !== undefined) {
        gameManager.updateRemainingTiles(Number(msg.remainingTiles));
      }

      if (msg.dealerSeat !== undefined) {
        gameManager.updateRoundInfo(Number(msg.dealerSeat), 1);
      }
    });

    // 摸牌响应（自己摸到的牌）
    networkManager.on('TILE_DRAWN', (msg: MessageData) => {
      const isMe = msg.playerId === gameManager.gameState.playerId;
      if (isMe && msg.tile !== undefined && msg.tile !== null) {
        this.handleTileDrawn(Number(msg.tile));
      } else if (!isMe && msg.seat !== undefined) {
        // 其他玩家摸牌通知
        const seat = Number(msg.seat);
        gameManager.opponentDrewTile(seat);
        this.showMessage(`${gameManager.getPlayerName(seat)} 摸了一张牌`);
      }
      if (msg.currentPlayer !== undefined) {
        gameManager.updateCurrentPlayer(Number(msg.currentPlayer));
      }
      if (msg.remainingTiles !== undefined) {
        gameManager.updateRemainingTiles(Number(msg.remainingTiles));
      }
    });

    // 其他玩家出牌
    networkManager.on('PLAYER_DISCARD', (msg: MessageData) => {
      if (msg.seat !== undefined && msg.tile !== undefined) {
        this.handleTileDiscarded(Number(msg.seat), Number(msg.tile));
      }
      if (msg.currentPlayer !== undefined) {
        gameManager.updateCurrentPlayer(Number(msg.currentPlayer));
      }
      if (msg.remainingTiles !== undefined) {
        gameManager.updateRemainingTiles(Number(msg.remainingTiles));
      }
    });

    // 游戏动作通知（碰/吃/杠/胡）
    networkManager.on('PLAYER_ACTION', (msg: MessageData) => {
      if (msg.seat !== undefined && msg.action) {
        this.handleGameAction(Number(msg.seat), String(msg.action), msg.tile ? Number(msg.tile) : undefined);
      }
      if (msg.currentPlayer !== undefined) {
        gameManager.updateCurrentPlayer(Number(msg.currentPlayer));
      }
      if (msg.remainingTiles !== undefined) {
        gameManager.updateRemainingTiles(Number(msg.remainingTiles));
      }
    });

    // 操作确认（自己动作的服务器反馈）
    networkManager.on('ACTION_CONFIRM', (msg: MessageData) => {
      console.info('操作确认:', JSON.stringify(msg));
      if (msg.accepted === false) {
        this.showMessage('操作被拒绝');
      }
    });

    networkManager.on('GAME_END', (msg: MessageData) => {
      if (msg.winner !== undefined) {
        this.handleGameEnd(Number(msg.winner), msg.scores as Record<string, number>);
      }
    });

    networkManager.on('ERROR', (msg: MessageData) => {
      const message = msg.message ? String(msg.message) : '操作失败';
      this.showMessage(message);
    });
  }

  // 更新游戏状态
  private updateGameStatus(): void {
    if (this.gameState.gameEnded) {
      if (!this.showGameOver) {
        // 延迟调用 ensureGameOver，确保 winner 信息已就绪
        if (this.gameState.isSinglePlayer) {
          const localGame = gameManager.getLocalGame();
          if (localGame) {
            this.handleLocalGameEnd();
          }
        }
        this.showGameOver = true;
      }
      return;
    }

    if (!this.gameState.gameStarted) {
      this.gameMessage = '等待游戏开始...';
      return;
    }

    // 检查本地引擎是否在等待反应中
    if (this.gameState.isSinglePlayer && gameManager.isLocalWaitingForReaction()) {
      // 显示等待反应状态
      const localGame = gameManager.getLocalGame();
      if (localGame) {
        const discarderSeat = localGame.getDiscarderSeat();
        const discarderName = gameManager.getPlayerName(discarderSeat);
        const tile = localGame.getState().lastDiscardedTile;
        if (tile) {
          this.gameMessage = `${discarderName} 打出 ${gameManager.getTileDisplayText(tile)}，等待响应...`;
        }
      }
      return;
    }

    if (this.gameState.currentPlayer === this.gameState.seat) {
      this.gameMessage = '轮到您出牌';
    } else {
      const currentPlayerName = gameManager.getCurrentPlayerName();
      this.gameMessage = `${currentPlayerName}的回合`;
    }

    // AI自动行动（仅单机模式，且不在等待反应中）
    if (this.gameState.isSinglePlayer &&
        this.gameState.currentPlayer !== this.gameState.seat &&
        this.gameState.gameStarted &&
        !this.gameState.gameEnded &&
        !gameManager.isLocalWaitingForReaction()) {
      this.processAITurn();
    }
  }

  // ==================== AI回合与反应系统（简化版） ====================

  // 处理AI回合
  private processAITurn(): void {
    const currentSeat = this.gameState.currentPlayer;
    const ai = this.aiPlayers.get(currentSeat);
    if (!ai) return;
    if (!this.gameState.isSinglePlayer) {
      // 多人模式：简单延迟后AI决策
      setTimeout(() => {
        const aiHand = gameManager.getPlayerHand(currentSeat);
        const decision = ai.makeDecision(aiHand, this.lastDiscardedTile, []);
        this.executeAIDecision(decision);
      }, 2000 + Math.random() * 3000);
      return;
    }

    // 单机模式：增加思考延迟
    setTimeout(() => {
      // 各种终止条件
      if (this.gameState.gameEnded || this.showGameOver) return;
      const localGame = gameManager.getLocalGame();
      if (!localGame || localGame.isGameEnded()) return;

      // AI摸牌出牌
      const discardedTile = gameManager.processAITurn((hand, discarded, melds) => {
        return ai.makeDecision(hand, discarded, melds);
      });

      // 检查游戏结束（AI可能自摸胡牌）
      if (localGame.isGameEnded()) {
        this.handleLocalGameEnd();
        return;
      }

      if (discardedTile !== null) {
        // AI出牌了 → 通知并检查人类能否碰/杠/胡
        this.lastDiscardedTile = discardedTile;
        const aiName = gameManager.getPlayerName(currentSeat);
        this.actionNotification = `${aiName} 打出 ${gameManager.getTileDisplayText(discardedTile)}`;

        const humanReactions = gameManager.getLocalReactions();
        if (humanReactions.length > 0) {
          // 人类有可操作项 → 停在这里，等人类选择
          this.availableActions = humanReactions;
          this.showOperationPanel = true;
        } else {
          // 人类无操作 → 自动推进
          gameManager.passLocalReaction();
          if (localGame.isWaitingForReaction()) {
            localGame.advanceToNextPlayer();
          }
          gameManager.syncLocalStateToUI();
          gameManager.syncAIHands();
          this.updateGameStatus();
        }
      } else {
        // AI没出牌（可能执行了碰/杠但已在processAITurn内部处理了反应）
        gameManager.syncLocalStateToUI();
        gameManager.syncAIHands();
        this.updateGameStatus();
      }
    }, 2000 + Math.random() * 3000);
  }

  // 人类弃牌后，串联检查所有AI的反应
  private handleAllReactionsAfterDiscard(): void {
    const localGame = gameManager.getLocalGame();
    if (!localGame) return;

    if (!localGame.isWaitingForReaction()) {
      if (localGame.isGameEnded()) {
        this.handleLocalGameEnd();
        return;
      }
      gameManager.syncLocalStateToUI();
      gameManager.syncAIHands();
      this.updateGameStatus();
      return;
    }

    // 串联检查：依次询问每个AI
    this.checkNextAIReaction(1);
  }

  // 按逆时针顺序检查一个AI的反应
  private checkNextAIReaction(aiIndex: number): void {
    const localGame = gameManager.getLocalGame();
    if (!localGame || !localGame.isWaitingForReaction()) {
      gameManager.syncLocalStateToUI();
      gameManager.syncAIHands();
      this.updateGameStatus();
      return;
    }

    if (aiIndex > 3) {
      // 所有AI都PASS了 → 推进
      if (localGame.isWaitingForReaction()) {
        localGame.advanceToNextPlayer();
      }
      gameManager.syncLocalStateToUI();
      gameManager.syncAIHands();
      this.updateGameStatus();
      return;
    }

    const discarderSeat = localGame.getDiscarderSeat();
    const aiSeat = (discarderSeat + aiIndex) % 4;

    // 跳过人类自己
    if (aiSeat === 0) {
      this.checkNextAIReaction(aiIndex + 1);
      return;
    }

    const ai = this.aiPlayers.get(aiSeat);
    if (!ai) {
      this.checkNextAIReaction(aiIndex + 1);
      return;
    }

    // 检查AI可用的反应
    const reactions = localGame.getAvailableReactions(aiSeat);
    const gameState = localGame.getState();
    const lastTile = gameState.lastDiscardedTile || 0;

    if (reactions.length > 0) {
      const aiHand = [...gameState.players[aiSeat].hand];
      const decision = ai.makeDecision(aiHand, lastTile, []);

      if (decision.action === 'WIN' || decision.action === 'KONG' ||
          decision.action === 'PONG') {
        // AI 执行反应
        const aiName = gameManager.getPlayerName(aiSeat);
        const actionTextMap: Record<string, string> = {
          'WIN': '胡牌！', 'KONG': '杠牌', 'PONG': '碰牌'
        };
        this.actionNotification = `${aiName} ${actionTextMap[decision.action]} ${gameManager.getTileDisplayText(lastTile)}`;
        this.showAnimationEffect(actionTextMap[decision.action], decision.action === 'WIN' ? '#e74c3c' : '#3498db');

        localGame.resolveReaction(aiSeat, decision.action);
        gameManager.syncLocalStateToUI();
        gameManager.syncAIHands();

        if (localGame.isGameEnded()) {
          this.handleLocalGameEnd();
          return;
        }
        // AI反应后成为当前玩家，继续AI回合
        this.updateGameStatus();
        return;
      }
    }

    // AI PASS → 延迟后检查下一个
    setTimeout(() => {
      gameManager.passLocalReaction();
      this.checkNextAIReaction(aiIndex + 1);
    }, 600);
  }

  // 显示动画
  private showReactionAnimation(action: string, playerSeat?: number, tile?: number): void {
    const animMap: Record<string, [string, string]> = {
      'WIN': ['胡！', '#e74c3c'],
      'KONG': ['杠！', '#f39c12'],
      'PONG': ['碰！', '#3498db'],
      'CHOW': ['吃！', '#2ecc71']
    };
    const animResult = animMap[action] || [action, '#4CAF50'];
    this.showAnimationEffect(animResult[0], animResult[1]);
    const soundMap: Record<string, string> = {
      'WIN': 'win', 'KONG': 'kong', 'PONG': 'pong', 'CHOW': 'chow'
    };
    this.playSound(soundMap[action] || 'discard');

    if (playerSeat !== undefined) {
      const actionTextMap: Record<string, string> = {
        'WIN': '胡牌！', 'KONG': '杠牌', 'PONG': '碰牌', 'CHOW': '吃牌'
      };
      const playerName = gameManager.getPlayerName(playerSeat);
      const tileText = tile ? ` ${gameManager.getTileDisplayText(tile)}` : '';
      this.actionNotification = `${playerName} ${actionTextMap[action] || action}${tileText}`;
    }
  }

  // 执行AI决策（多人模式）
  private executeAIDecision(decision: AIDecision): void {
    switch (decision.action) {
      case 'DISCARD':
        if (decision.tile) {
          this.sendDiscard(decision.tile);
        }
        break;
      case 'PONG':
        this.sendAction('PONG', this.lastDiscardedTile);
        break;
      // 吃牌已禁用
        break;
      case 'KONG':
        this.sendAction('KONG', this.lastDiscardedTile);
        break;
      case 'WIN':
        this.sendAction('WIN', this.lastDiscardedTile);
        break;
      default:
        break;
    }
  }

  // 单机模式游戏结束处理
  private handleLocalGameEnd(): void {
    if (this.showGameOver) return; // 防止重复调用

    const localGame = gameManager.getLocalGame();
    if (!localGame) return;

    const gameState = localGame.getState();
    const winner = gameState.winner;

    if (winner !== undefined) {
      const players = this.gameState.players.map(p => p.nickname);
      const winnerName = gameManager.getPlayerName(winner);

      const scores: Record<string, number> = {};
      for (const player of gameState.players) {
        scores[player.nickname] = player.score;
      }

      const duration = this.gameStartTime > 0 ? Math.floor((Date.now() - this.gameStartTime) / 1000) : 0;

      statisticsManager.recordGame({
        gameId: `game-${Date.now()}`,
        timestamp: Date.now(),
        players: players,
        winner: winnerName,
        scores: scores,
        duration: duration
      });

      this.gameOverWinner = winnerName;
      this.gameOverScores = scores;
      this.actionNotification = `🏆 ${winnerName} 胡牌获胜！`;
    }

    this.showGameOver = true;
    this.showAnimationEffect('🎉 胡牌！', '#FFD700');
    this.playSound('win');
  }

  // 摸牌
  private drawTile(): void {
    if (this.gameState.isSinglePlayer) {
      const tile = gameManager.localDrawTile();
      if (tile !== null) {
        this.showMessage(`摸到 ${gameManager.getTileDisplayText(tile)}`);
        this.playSound('draw');
      }
    } else {
      networkManager.send('DRAW_TILE', { type: 'DRAW_TILE' });
    }
  }

  // 选择牌
  private selectTile(tile: number): void {
    this.selectedTile = tile;
  }

  // 出牌
  private discardTile(): void {
    if (this.selectedTile !== 0) {
      if (this.gameState.isSinglePlayer) {
        gameManager.localDiscardTile(this.selectedTile);
        this.lastDiscardedTile = this.selectedTile;
        this.playSound('discard');
        this.selectedTile = 0;

        // 检查游戏是否结束（手牌为空）
        const localGame = gameManager.getLocalGame();
        if (localGame && localGame.isGameEnded()) {
          this.handleLocalGameEnd();
          return;
        }

        // 处理AI对弃牌的反应（串联延迟检查）
        this.handleAllReactionsAfterDiscard();
      } else {
        const tile = this.selectedTile;
        const newHand = this.gameState.myHand.filter(t => t !== tile);
        gameManager.updateMyHand(newHand);
        gameManager.addDiscardTile(tile.toString());
        this.lastDiscardedTile = tile;
        this.playSound('discard');
        this.sendDiscard(tile);
        this.selectedTile = 0;
      }
    }
  }

  // 检查本地AI对上家出牌的响应
  private checkLocalAIReactions(discardedTile: number): void {
    const localGame = gameManager.getLocalGame();
    if (!localGame) return;

    // 先检查人类玩家是否可以响应（碰/吃/杠/胡）
    const actions = gameManager.getLocalAvailableActions(discardedTile);
    this.availableActions = actions;
    this.showOperationPanel = actions.length > 0;
  }

  // 发送出牌指令（多人模式）
  private sendDiscard(tile: number): void {
    networkManager.send('DISCARD_TILE', {
      type: 'DISCARD_TILE',
      tile: tile
    });
  }

  // 发送动作指令（多人模式）
  private sendAction(action: string, tile?: number): void {
    networkManager.send('GAME_ACTION', {
      type: 'GAME_ACTION',
      action: action,
      tile: tile
    });
  }

  // 处理摸牌
  private handleTileDrawn(tile: number): void {
    const newHand = [...this.gameState.myHand, tile];
    gameManager.updateMyHand(newHand);
    this.showMessage(`摸到 ${gameManager.getTileDisplayText(tile)}`);
    this.playSound('draw');
  }

  // 处理出牌（多人模式：收到 PLAYER_DISCARD — 仅其他玩家）
  private handleTileDiscarded(seat: number, tile: number): void {
    this.lastDiscardedTile = tile;

    // 多人模式：自己的出牌已在 discardTile() 中乐观处理，这里只处理其他玩家
    if (seat !== gameManager.gameState.seat) {
      gameManager.addPlayerDiscard(seat, tile);
      const playerName = gameManager.getPlayerName(seat);
      this.showMessage(`${playerName} 打出 ${gameManager.getTileDisplayText(tile)}`);

      // 检查是否可以碰/吃/杠/胡
      this.checkAvailableActions(tile);
    }
  }

  // 处理游戏动作（多人模式：收到 PLAYER_ACTION）
  private handleGameAction(seat: number, action: string, tile?: number): void {
    const playerName = gameManager.getPlayerName(seat);
    let message = '';
    let animationText = '';
    let animationColor = '#4CAF50';

    switch (action) {
      case 'PONG':
        message = `${playerName} 碰牌`;
        animationText = '碰！';
        animationColor = '#3498db';
        this.playSound('pong');
        break;
      case 'CHOW':
        message = `${playerName} 吃牌`;
        animationText = '吃！';
        animationColor = '#2ecc71';
        this.playSound('chow');
        break;
      case 'KONG':
        message = `${playerName} 杠牌`;
        animationText = '杠！';
        animationColor = '#f39c12';
        this.playSound('kong');
        break;
      case 'WIN':
        message = `${playerName} 胡牌！`;
        animationText = '胡！';
        animationColor = '#e74c3c';
        this.playSound('win');
        break;
      case 'DRAW':
        // 摸牌通知已由 TILE_DRAWN 处理，这里忽略
        break;
    }

    if (message) {
      this.showMessage(message);
      if (animationText) {
        this.showAnimationEffect(animationText, animationColor);
      }
    }
  }

  // 处理游戏结束
  private handleGameEnd(winner: number, scores?: Record<string, number>): void {
    gameManager.setGameEnded(true, winner);

    // 构建 nickname → score 的映射用于显示
    const displayScores: Record<string, number> = {};

    if (scores) {
      // scores 是 playerId → score，需要转换为 seat → score
      Object.entries(scores).forEach((entry) => {
        const playerId = entry[0];
        const score = entry[1];
        const seat = gameManager.getSeatByPlayerId(playerId);
        if (seat >= 0) {
          gameManager.updatePlayerScore(seat, score);
          const playerName = gameManager.getPlayerName(seat);
          displayScores[playerName] = score;
        }
      });
      this.gameOverScores = displayScores;

      // 记录统计数据
      const players = this.gameState.players.map(p => p.nickname);
      const winnerName = gameManager.getPlayerName(winner);

      const duration = this.gameStartTime > 0 ? Math.floor((Date.now() - this.gameStartTime) / 1000) : 0;

      statisticsManager.recordGame({
        gameId: `game-${Date.now()}`,
        timestamp: Date.now(),
        players: players,
        winner: winnerName,
        scores: displayScores,
        duration: duration
      });
    }

    const winnerName = gameManager.getPlayerName(winner);
    this.gameOverWinner = winnerName;
    this.showGameOver = true;
    this.actionNotification = `🏆 ${winnerName} 胡牌获胜！`;

    // 显示获胜动画
    this.showAnimationEffect('🎉 胡牌！', '#FFD700');
    this.playSound('win');
  }

  // 检查可用操作
  private checkAvailableActions(discardedTile: number): void {
    let actions: string[];
    if (this.gameState.isSinglePlayer) {
      actions = gameManager.getLocalAvailableActions(discardedTile);
    } else {
      actions = gameManager.getAvailableActions(discardedTile);
    }
    this.availableActions = actions;
    this.showOperationPanel = actions.length > 0;
  }

  // 执行操作
  private performAction(action: string): void {
    console.info(`执行操作: ${action}`);

    switch (action) {
      case 'PONG':
        this.showReactionAnimation('PONG', this.gameState.seat, this.lastDiscardedTile);
        if (this.gameState.isSinglePlayer) {
          gameManager.resolveLocalReaction('PONG');
        } else {
          gameManager.multiPong(this.lastDiscardedTile);
        }
        break;
      case 'CHOW':
        // 吃牌已禁用
        if (this.gameState.isSinglePlayer) {
          // 吃牌已禁用
        } else {
          const tile = this.lastDiscardedTile;
          const combos = [
            [tile - 2, tile - 1, tile],
            [tile - 1, tile, tile + 1],
            [tile, tile + 1, tile + 2]
          ];
          const hand = this.gameState.myHand;
          let chosenCombo: number[] | null = null;
          for (const combo of combos) {
            const needed = combo.filter(t => t !== tile);
            if (needed.every(t => hand.includes(t))) {
              chosenCombo = combo;
              break;
            }
          }
          if (chosenCombo) {
            // 吃牌已禁用
          }
        }
        break;
      case 'KONG':
        this.showReactionAnimation('KONG', this.gameState.seat, this.lastDiscardedTile);
        if (this.gameState.isSinglePlayer) {
          gameManager.resolveLocalReaction('KONG');
        } else {
          const handCount = this.gameState.myHand.filter(t => t === this.lastDiscardedTile).length;
          gameManager.multiKong(this.lastDiscardedTile, handCount >= 4);
        }
        break;
      case 'WIN':
        this.showReactionAnimation('WIN', this.gameState.seat, this.lastDiscardedTile);
        if (this.gameState.isSinglePlayer) {
          gameManager.resolveLocalReaction('WIN');
          const localGame = gameManager.getLocalGame();
          if (localGame && localGame.isGameEnded()) {
            this.handleLocalGameEnd();
            this.showOperationPanel = false;
            this.availableActions = [];
            return;
          }
        }
        break;
    }

    if (!this.gameState.isSinglePlayer) {
      this.sendAction(action, this.lastDiscardedTile);
    }

    this.showOperationPanel = false;
    this.availableActions = [];

    // 单机模式：操作后检查游戏状态
    if (this.gameState.isSinglePlayer) {
      const localGame = gameManager.getLocalGame();
      if (localGame && !localGame.isGameEnded()) {
        // 碰/杠后人类成为当前玩家，需要出牌（已摸牌在手）
        this.updateGameStatus();
      }
    }
  }

  // 获取操作文本
  private getActionText(action: string): string {
    const actionMap: Record<string, string> = {
      'PONG': '碰',
      'CHOW': '吃', 
      'KONG': '杠',
      'WIN': '胡',
      'DRAW': '摸牌',
      'DISCARD': '出牌'
    };
    return actionMap[action] || action;
  }

  // 获取操作颜色
  private getActionColor(action: string): string {
    const colorMap: Record<string, string> = {
      'WIN': '#e74c3c',
      'PONG': '#3498db',
      'CHOW': '#2ecc71',
      'KONG': '#f39c12',
      'DRAW': '#4CAF50',
      'DISCARD': '#2196F3'
    };
    return colorMap[action] || '#9b59b6';
  }

  // 判断是否需要出牌（而非摸牌）
  private needDiscard(): boolean {
    const justReacted = this.gameState.lastAction &&
      this.gameState.lastAction.player === this.gameState.seat &&
      (this.gameState.lastAction.action === 'PONG' ||
       this.gameState.lastAction.action === 'KONG' ||
       this.gameState.lastAction.action === 'CHOW');
    return justReacted || this.gameState.myHand.length >= 14;
  }

  // 获取动作显示文本
  private getActionDisplayText(): string {
    if (!this.gameState.lastAction) return '';
    const action = this.gameState.lastAction;
    const playerName = gameManager.getPlayerName(action.player);
    const tileText = action.tile ? gameManager.getTileDisplayText(action.tile) : '';
    const actionMap: Record<string, string> = {
      'PONG': `${playerName} 碰了 ${tileText}`,
      'KONG': `${playerName} 杠了 ${tileText}`,
      'CHOW': `${playerName} 吃了 ${tileText}`,
      'WIN': `${playerName} 胡牌！${tileText}`
    };
    return actionMap[action.action] || '';
  }

  // 获取动作显示颜色
  private getActionDisplayColor(): string {
    if (!this.gameState.lastAction) return '#fff';
    const colorMap: Record<string, string> = {
      'PONG': '#3498db',
      'KONG': '#f39c12',
      'CHOW': '#2ecc71',
      'WIN': '#e74c3c'
    };
    return colorMap[this.gameState.lastAction.action] || '#fff';
  }

  // 显示消息
  private showMessage(message: string): void {
    this.gameMessage = message;
    setTimeout(() => {
      this.gameMessage = '';
    }, 3000);
  }

  // 显示动画效果
  private showAnimationEffect(text: string, color: string = '#4CAF50'): void {
    this.animationText = text;
    this.animationColor = color;
    this.showAnimation = true;
    
    setTimeout(() => {
      this.showAnimation = false;
    }, 1500);
  }

  // 播放音效（模拟）
  private playSound(soundType: string): void {
    console.info(`播放音效: ${soundType}`);
    // TODO: 集成实际音效系统
    // 可以使用 @kit.AudioKit 实现真实音效
  }

  // PASS反应（跳过碰/杠/胡机会）
  private passReaction(): void {
    if (this.gameState.isSinglePlayer) {
      gameManager.passLocalReaction();
      const localGame = gameManager.getLocalGame();
      if (localGame && localGame.isWaitingForReaction()) {
        localGame.advanceToNextPlayer();
      }
      gameManager.syncLocalStateToUI();
      gameManager.syncAIHands();
    }
    this.showOperationPanel = false;
    this.availableActions = [];
    this.actionNotification = '';
    this.updateGameStatus();
  }

  // 获取对手牌组
  private getOpponentMelds(seat: number): number[][] {
    return gameManager.getSeatMelds(seat);
  }

  // 返回大厅
  private returnToLobby(): void {
    if (!this.gameState.isSinglePlayer) {
      networkManager.disconnect();
    }
    gameManager.reset();
    try {
      router.back();
    } catch (e) {
      console.error('Router back error:', e);
    }
  }

  // 显示游戏规则
  private showGameRules(): void {
    try {
      promptAction.showDialog({
        title: '麻将游戏规则',
        message: '基本规则：\n1. 四人麻将，轮流摸牌出牌\n2. 可以吃、碰、杠、胡\n3. 胡牌需要满足特定牌型\n4. 七对子、碰碰胡等特殊牌型有额外分数',
        buttons: [{ text: '确定', color: '#4CAF50' }]
      });
    } catch (e) {
      console.error('Show dialog error:', e);
    }
  }

  // 获取玩家颜色
  private getPlayerColor(seat: number): string {
    const colors = ['#e74c3c', '#3498db', '#2ecc71', '#f39c12'];
    return colors[seat % colors.length];
  }

  // 获取玩家名称
  private getPlayerName(seat: number): string {
    return gameManager.getPlayerName(seat);
  }

  // 根据玩家ID获取座位号
  private getSeatByPlayerId(playerId: string): number {
    const player = this.gameState.players.find(p => 
      p.nickname === playerId || p.seat.toString() === playerId
    );
    return player ? player.seat : 0;
  }

  // 根据座位号获取玩家名称
  private getPlayerNameBySeat(seat: number): string {
    return this.getPlayerName(seat);
  }

  // 获取对手手牌数量
  private getOpponentHandCount(seat: number): number {
    return gameManager.getOpponentHandCount(seat);
  }

  // 获取指定座位的弃牌
  private getDiscardedTiles(seat: number): number[] {
    if (this.gameState.isSinglePlayer || this.gameState.isSinglePlayerServer) {
      // 本地模式或服务器单人模式
      return gameManager.getSeatDiscarded(seat);
    }
    // 多人模式
    return gameManager.getPlayerDiscarded(seat);
  }
}