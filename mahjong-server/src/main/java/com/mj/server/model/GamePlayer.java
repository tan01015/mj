package com.mj.server.model;

import lombok.Data;

@Data
public class GamePlayer {
    private String playerId;
    private String nickname;
    private int seat;
    private boolean ready;
    private boolean online;
    
    public GamePlayer(String playerId, String nickname) {
        this.playerId = playerId;
        this.nickname = nickname;
        this.ready = false;
        this.online = true;
    }
}
