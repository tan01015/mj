package com.mj.server.model;

import lombok.Data;
import java.util.*;

@Data
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
