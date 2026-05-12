package com.mj.server.model;

import lombok.Data;

@Data
public class Player {
    private String playerId;
    private String nickname;
    private int seat;
    private boolean ready;
    private boolean online;
    private String sessionId;
    
    public Player() {
        this.ready = false;
        this.online = true;
    }
    
    public Player(String playerId, String nickname) {
        this.playerId = playerId;
        this.nickname = nickname;
        this.ready = false;
        this.online = true;
    }
}
