package com.mj.server.model;

import java.util.*;

public class Room {
    private String roomId;
    private String hostId;
    private String gameMode;
    private int maxPlayers;
    private Map<Integer, Player> players;
    private boolean gameStarted;
    private long createTime;
    
    public Room() {
        this.players = new HashMap<>();
        this.gameStarted = false;
        this.createTime = System.currentTimeMillis();
    }
    
    // Getters and Setters
    public String getRoomId() { return roomId; }
    public void setRoomId(String roomId) { this.roomId = roomId; }
    public String getHostId() { return hostId; }
    public void setHostId(String hostId) { this.hostId = hostId; }
    public String getGameMode() { return gameMode; }
    public void setGameMode(String gameMode) { this.gameMode = gameMode; }
    public int getMaxPlayers() { return maxPlayers; }
    public void setMaxPlayers(int maxPlayers) { this.maxPlayers = maxPlayers; }
    public Map<Integer, Player> getPlayers() { return players; }
    public void setPlayers(Map<Integer, Player> players) { this.players = players; }
    public boolean isGameStarted() { return gameStarted; }
    public void setGameStarted(boolean gameStarted) { this.gameStarted = gameStarted; }
    public long getCreateTime() { return createTime; }
    
    public boolean isFull() {
        return players.size() >= maxPlayers;
    }
    
    public boolean isEmpty() {
        return players.isEmpty();
    }
    
    public void addPlayer(Player player) {
        int seat = findEmptySeat();
        if (seat != -1) {
            player.setSeat(seat);
            players.put(seat, player);
        }
    }
    
    private int findEmptySeat() {
        for (int i = 0; i < maxPlayers; i++) {
            if (!players.containsKey(i)) {
                return i;
            }
        }
        return -1;
    }
    
    public void removePlayer(String playerId) {
        players.values().removeIf(p -> p.getPlayerId().equals(playerId));
    }
}
