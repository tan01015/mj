import { networkManager, MessageData, SendData } from '../utils/NetworkManager';
import { gameManager, GamePlayer, GameManagerState } from '../utils/GameManager';
import { MahjongRules, MahjongTile } from '../engine/MahjongRules';
import { AdvancedAI, AIDifficulty, AIDecision } from '../ai/AdvancedAI';
import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';

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
  
  private unsubscribe: () => void = () => {};
  private aiPlayers: Map<number, AdvancedAI> = new Map();

  aboutToAppear() {
    this.unsubscribe = gameManager.subscribe((state: GameManagerState) => {
      this.gameState = state;
      this.updateGameStatus();
    });

    this.setupNetworkListeners();
    this.initializeAIPlayers();
    this.updateGameStatus();
  }

  aboutToDisappear() {
    this.unsubscribe();
    networkManager.clearHandlers();
  }

  build() {
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

      // 中间弃牌区域
      Column() {
        Text('弃牌区')
          .fontSize(16)
          .fontColor('#ffffffcc')
          .margin({ bottom: 10 })
        
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
          ForEach(this.gameState.myDiscarded, (tile: number) => {
            this.buildTile(tile, false)
          }, (tile: number) => tile.toString())
        }
        .width('80%')
        .height(80)
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
        
        Row() {
          ForEach(this.gameState.myHand, (tile: number) => {
            this.buildTile(tile, true)
          }, (tile: number) => tile.toString())
        }
        .width('90%')
        .height(120)
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .height('35%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

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
  buildOpponentArea(seat: number): void {
    Column() {
      Text(this.getPlayerName(seat))
        .fontSize(16)
        .fontColor('#fff')
        .margin({ bottom: 10 })
      
      Text(`手牌: ${this.getOpponentHandCount(seat)}张`)
        .fontSize(12)
        .fontColor('#ffffffcc')
      
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
        Button('摸牌')
          .width('100%')
          .height(45)
          .fontSize(16)
          .backgroundColor('#4CAF50')
          .color('#ffffff')
          .borderRadius(8)
          .onClick(() => {
            this.drawTile();
          })
          .margin({ bottom: 10 })

        if (this.selectedTile) {
          Button('出牌')
            .width('100%')
            .height(45)
            .fontSize(16)
            .backgroundColor('#2196F3')
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
              .color('#ffffff')
              .borderRadius(6)
              .onClick(() => {
                this.performAction(action);
              })
              .margin({ bottom: 8 })
          }, (action: string) => action)
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
        .color('#ffffff')
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
    networkManager.on('TILE_DRAWN', (msg: MessageData) => {
      if (msg.playerId === gameManager.gameState.playerId && msg.tile) {
        this.handleTileDrawn(msg.tile);
      }
    });

    networkManager.on('TILE_DISCARDED', (msg: MessageData) => {
      if (msg.playerId && msg.tile) {
        this.handleTileDiscarded(msg.playerId, msg.tile);
      }
    });

    networkManager.on('GAME_ACTION', (msg: MessageData) => {
      if (msg.playerId && msg.action) {
        this.handleGameAction(msg.playerId, msg.action, msg.tile);
      }
    });

    networkManager.on('GAME_END', (msg: MessageData) => {
      if (msg.winner !== undefined) {
        this.handleGameEnd(msg.winner, msg.scores);
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
      this.showGameOver = true;
      return;
    }

    if (!this.gameState.gameStarted) {
      this.gameMessage = '等待游戏开始...';
      return;
    }

    if (this.gameState.currentPlayer === this.gameState.seat) {
      this.gameMessage = '轮到您出牌';
    } else {
      const currentPlayerName = gameManager.getCurrentPlayerName();
      this.gameMessage = `${currentPlayerName}的回合`;
    }

    // AI自动行动
    if (this.gameState.currentPlayer !== this.gameState.seat && 
        this.gameState.gameStarted && 
        !this.gameState.gameEnded) {
      this.processAITurn();
    }
  }

  // 处理AI回合
  private processAITurn(): void {
    const ai = this.aiPlayers.get(this.gameState.currentPlayer);
    if (ai) {
      setTimeout(() => {
        const decision = ai.makeDecision(this.gameState.myHand, this.lastDiscardedTile);
        this.executeAIDecision(decision);
      }, 1000 + Math.random() * 2000); // AI思考时间
    }
  }

  // 执行AI决策
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
      case 'CHOW':
        this.sendAction('CHOW', this.lastDiscardedTile);
        break;
      case 'KONG':
        this.sendAction('KONG', this.lastDiscardedTile);
        break;
      case 'WIN':
        this.sendAction('WIN', this.lastDiscardedTile);
        break;
      default:
        // AI选择跳过
        break;
    }
  }

  // 摸牌
  private drawTile(): void {
    networkManager.send('DRAW_TILE', { type: 'DRAW_TILE' });
  }

  // 选择牌
  private selectTile(tile: number): void {
    this.selectedTile = tile;
  }

  // 出牌
  private discardTile(): void {
    if (this.selectedTile) {
      this.sendDiscard(this.selectedTile);
      this.selectedTile = undefined;
    }
  }

  // 发送出牌指令
  private sendDiscard(tile: number): void {
    networkManager.send('DISCARD_TILE', { 
      type: 'DISCARD_TILE', 
      tile: tile 
    });
  }

  // 发送动作指令
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
  }

  // 处理出牌
  private handleTileDiscarded(playerId: string, tile: number): void {
    this.lastDiscardedTile = tile;
    
    if (playerId === gameManager.gameState.playerId) {
      // 自己出牌，从手牌移除
      const newHand = this.gameState.myHand.filter(t => t !== tile);
      gameManager.updateMyHand(newHand);
      gameManager.addDiscardTile(tile.toString());
    }
    
    const seat = this.getSeatByPlayerId(playerId);
    this.showMessage(`${this.getPlayerNameBySeat(seat)} 打出 ${gameManager.getTileDisplayText(tile)}`);
    
    // 检查可用的操作
    if (playerId !== gameManager.gameState.playerId) {
      this.checkAvailableActions(tile);
    }
  }

  // 处理游戏动作
  private handleGameAction(playerId: string, action: string, tile?: number): void {
    const playerName = this.getPlayerNameBySeat(this.getSeatByPlayerId(playerId));
    let message = '';
    
    switch (action) {
      case 'PONG':
        message = `${playerName} 碰牌`;
        break;
      case 'CHOW':
        message = `${playerName} 吃牌`;
        break;
      case 'KONG':
        message = `${playerName} 杠牌`;
        break;
      case 'WIN':
        message = `${playerName} 胡牌！`;
        break;
    }
    
    if (message) {
      this.showMessage(message);
    }
  }

  // 处理游戏结束
  private handleGameEnd(winner: number, scores?: Record<string, number>): void {
    gameManager.setGameEnded(true, winner);
    
    if (scores) {
      Object.entries(scores).forEach((entry) => {
        const playerId = entry[0];
        const score = entry[1];
        const seat = this.getSeatByPlayerId(playerId);
        gameManager.updatePlayerScore(seat, score);
      });
    }
    
    const winnerName = gameManager.getPlayerName(winner);
    this.showMessage(`游戏结束！${winnerName}获胜！`);
  }

  // 检查可用操作
  private checkAvailableActions(discardedTile: number): void {
    const actions = gameManager.getAvailableActions(discardedTile);
    this.availableActions = actions;
    this.showOperationPanel = actions.length > 0;
  }

  // 执行操作
  private performAction(action: string): void {
    switch (action) {
      case 'PONG':
      case 'CHOW':
      case 'KONG':
      case 'WIN':
        this.sendAction(action, this.lastDiscardedTile);
        break;
    }
    
    this.showOperationPanel = false;
    this.availableActions = [];
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

  // 显示消息
  private showMessage(message: string): void {
    this.gameMessage = message;
    setTimeout(() => {
      this.gameMessage = '';
    }, 3000);
  }

  // 返回大厅
  private returnToLobby(): void {
    networkManager.disconnect();
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
        buttons: [{ text: '确定' }]
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
    // 简化处理，实际应该从服务器获取
    return 13; // 标准麻将手牌数量
  }
}