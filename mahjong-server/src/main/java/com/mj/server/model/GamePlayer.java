package com.mj.server.model;

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
    
    // Getters and Setters
    public String getPlayerId() { return playerId; }
    public void setPlayerId(String playerId) { this.playerId = playerId; }
    public String getNickname() { return nickname; }
    public void setNickname(String nickname) { this.nickname = nickname; }
    public int getSeat() { return seat; }
    public void setSeat(int seat) { this.seat = seat; }
    public boolean isReady() { return ready; }
    public void setReady(boolean ready) { this.ready = ready; }
    public boolean isOnline() { return online; }
    public void setOnline(boolean online) { this.online = online; }
}
