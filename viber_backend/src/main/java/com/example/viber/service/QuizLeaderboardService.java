package com.example.viber.service;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.viber.dto.LeaderboardEntry;
import com.example.viber.dto.LeaderboardResponse;
import com.example.viber.model.Friendship;
import com.example.viber.model.User;
import com.example.viber.repository.FriendshipRepository;
import com.example.viber.repository.QuizGameRepository;

/**
 * Clasificaciones del quiz. Dos ejes:
 *  - scope:  mundial (todos) o entre amigos (uno mismo + amistades aceptadas).
 *  - period: diario (hoy) o mensual (lo que va de mes).
 *
 * Solo puntúa el reto diario; la práctica no entra (es infinita → farmeable).
 * Todo se calcula al leer a partir de los puntos congelados en cada partida:
 * a la escala de este proyecto (una clase) sobra y evita desnormalizar.
 */
@Service
public class QuizLeaderboardService {

    /** Cuántas filas se devuelven como máximo para pintar la tabla. */
    private static final int TOP_N = 100;

    @Autowired private QuizGameRepository   quizGameRepository;
    @Autowired private FriendshipRepository friendshipRepository;

    @Transactional(readOnly = true)
    public LeaderboardResponse getLeaderboard(User user, String scopeRaw, String periodRaw) {
        String scope  = "friends".equalsIgnoreCase(scopeRaw) ? "friends" : "world";
        String period = "month".equalsIgnoreCase(periodRaw)  ? "month"   : "daily";

        LocalDate today = LocalDate.now();
        LocalDate from  = period.equals("month") ? today.withDayOfMonth(1) : today;
        LocalDate to    = today;

        List<LeaderboardEntry> raw = scope.equals("friends")
            ? quizGameRepository.leaderboardForUsers(
                  from, to, friendIdsIncludingSelf(user), PageRequest.of(0, TOP_N))
            : quizGameRepository.leaderboard(from, to, PageRequest.of(0, TOP_N));

        List<LeaderboardResponse.Row> rows = new ArrayList<>(raw.size());
        Integer myRank = null;
        for (int i = 0; i < raw.size(); i++) {
            LeaderboardEntry e = raw.get(i);
            boolean isMe = e.getUserId().equals(user.getId());
            if (isMe) myRank = i + 1;
            rows.add(toRow(i + 1, e, isMe));
        }

        LeaderboardResponse resp = new LeaderboardResponse();
        resp.setScope(scope);
        resp.setPeriod(period);
        resp.setEntries(rows);
        resp.setMe(buildMe(user, from, to, myRank));
        return resp;
    }

    // ── Helpers ─────────────────────────────────────────────────────────────────

    private LeaderboardResponse.Row toRow(int rank, LeaderboardEntry e, boolean isMe) {
        LeaderboardResponse.Row row = new LeaderboardResponse.Row();
        row.setRank(rank);
        row.setUserId(e.getUserId());
        row.setUsername(e.getUsername());
        row.setDisplayName(e.getDisplayName());
        row.setAvatarUrl(e.getAvatarUrl());
        row.setPoints(e.getPoints());
        row.setSolvedCount(e.getSolvedCount());
        row.setMe(isMe);
        return row;
    }

    /** Resumen del propio usuario: puntos/rango en la ventana + racha (global). */
    private LeaderboardResponse.Me buildMe(User user, LocalDate from, LocalDate to, Integer myRank) {
        LeaderboardEntry agg = quizGameRepository.myAggregate(user, from, to).orElse(null);

        LeaderboardResponse.Me me = new LeaderboardResponse.Me();
        me.setRank(myRank);                 // null si está fuera del top mostrado
        me.setRanked(agg != null);
        me.setPoints(agg != null ? agg.getPoints() : 0L);
        me.setSolvedCount(agg != null ? agg.getSolvedCount() : 0L);

        List<LocalDate> solved = quizGameRepository.solvedDailyDates(user);
        me.setCurrentStreak(currentStreak(solved));
        me.setBestStreak(bestStreak(solved));
        return me;
    }

    private Set<Long> friendIdsIncludingSelf(User user) {
        Set<Long> ids = new HashSet<>();
        ids.add(user.getId());
        for (Friendship f : friendshipRepository.findAcceptedByUser(user, Friendship.Status.ACCEPTED)) {
            Long other = f.getRequester().getId().equals(user.getId())
                ? f.getAddressee().getId()
                : f.getRequester().getId();
            ids.add(other);
        }
        return ids;
    }

    /** Días seguidos resolviendo, contando hacia atrás desde hoy (o ayer si hoy aún no). */
    static int currentStreak(List<LocalDate> solvedDates) {
        Set<LocalDate> set = new HashSet<>(solvedDates);
        LocalDate cursor = LocalDate.now();
        if (!set.contains(cursor)) cursor = cursor.minusDays(1); // la racha sigue viva si fue ayer
        int streak = 0;
        while (set.contains(cursor)) {
            streak++;
            cursor = cursor.minusDays(1);
        }
        return streak;
    }

    /** Racha más larga jamás conseguida. */
    static int bestStreak(List<LocalDate> solvedDates) {
        Set<LocalDate> set = new HashSet<>(solvedDates);
        int best = 0;
        for (LocalDate d : set) {
            // Solo arrancamos a contar desde el principio de cada racha (sin día previo)
            if (set.contains(d.minusDays(1))) continue;
            int len = 0;
            for (LocalDate c = d; set.contains(c); c = c.plusDays(1)) len++;
            best = Math.max(best, len);
        }
        return best;
    }
}
