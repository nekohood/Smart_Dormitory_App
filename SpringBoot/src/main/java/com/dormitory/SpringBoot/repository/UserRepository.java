package com.dormitory.SpringBoot.repository;

import com.dormitory.SpringBoot.domain.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

/**
 * 사용자 데이터 액세스 인터페이스 - 완성된 버전
 */
@Repository
public interface UserRepository extends JpaRepository<User, String> {

    /**
     * 사용자 ID 존재 여부 확인
     */
    boolean existsById(String id);

    /**
     * 이메일 해시로 사용자 조회 (성능 개선)
     */
    Optional<User> findByEmailHash(String emailHash);

    /**
     * 활성 사용자 조회
     */
    List<User> findByIsActiveTrue();

    /**
     * 관리자 사용자 조회
     */
    List<User> findByIsAdminTrueAndIsActiveTrue();

    /**
     * 일반 사용자 조회
     */
    List<User> findByIsAdminFalseAndIsActiveTrue();

    /**
     * 방 번호로 사용자 조회
     */
    Optional<User> findByRoomNumber(String roomNumber);

    /**
     * 이메일로 사용자 조회 (암호화된 이메일) - 성능 문제로 사용하지 않음
     */
    // Optional<User> findByEmail(String encryptedEmail);

    /**
     * 잠긴 계정 조회
     */
    List<User> findByIsLockedTrueAndLockedUntilAfter(LocalDateTime now);

    /**
     * 잠금 해제 가능한 계정 조회
     */
    List<User> findByIsLockedTrueAndLockedUntilBefore(LocalDateTime now);

    /**
     * 특정 기간 이후 로그인한 사용자 조회
     */
    List<User> findByLastLoginAtAfter(LocalDateTime dateTime);

    /**
     * 특정 기간 이전에 생성된 사용자 조회
     */
    List<User> findByCreatedAtBefore(LocalDateTime dateTime);

    /**
     * 비밀번호 만료 대상 사용자 조회 (90일 이상)
     */
    @Query("SELECT u FROM User u WHERE u.passwordChangedAt < :expiryDate OR " +
            "(u.passwordChangedAt IS NULL AND u.createdAt < :expiryDate)")
    List<User> findUsersWithExpiredPassword(@Param("expiryDate") LocalDateTime expiryDate);

    /**
     * 활성 사용자 수 조회
     */
    @Query("SELECT COUNT(u) FROM User u WHERE u.isActive = true")
    long countActiveUsers();

    /**
     * 관리자 수 조회
     */
    @Query("SELECT COUNT(u) FROM User u WHERE u.isAdmin = true AND u.isActive = true")
    long countActiveAdmins();

    /**
     * 오늘 가입한 사용자 수
     */
    @Query("SELECT COUNT(u) FROM User u WHERE FUNCTION('DATE', u.createdAt) = CURRENT_DATE")
    long countTodayRegistrations();

    /**
     * 이번 주 가입한 사용자 수
     */
    @Query("SELECT COUNT(u) FROM User u WHERE u.createdAt >= :startOfWeek")
    long countThisWeekRegistrations(@Param("startOfWeek") LocalDateTime startOfWeek);

    /**
     * 이번 달 가입한 사용자 수
     */
    @Query("SELECT COUNT(u) FROM User u WHERE u.createdAt >= :startOfMonth")
    long countThisMonthRegistrations(@Param("startOfMonth") LocalDateTime startOfMonth);

    /**
     * 특정 기간 동안 로그인한 사용자 수
     */
    @Query("SELECT COUNT(DISTINCT u) FROM User u WHERE u.lastLoginAt BETWEEN :startDate AND :endDate")
    long countActiveUsersBetween(@Param("startDate") LocalDateTime startDate,
                                 @Param("endDate") LocalDateTime endDate);

    /**
     * 방 번호로 사용자 검색 (LIKE 검색)
     */
    List<User> findByRoomNumberContainingIgnoreCase(String roomNumber);

    /**
     * 사용자 ID로 검색 (LIKE 검색)
     */
    List<User> findByIdContainingIgnoreCase(String id);

    /**
     * 최근 로그인 순으로 사용자 조회
     */
    List<User> findByIsActiveTrueOrderByLastLoginAtDesc();

    /**
     * 생성일 순으로 사용자 조회
     */
    List<User> findByIsActiveTrueOrderByCreatedAtDesc();

    /**
     * 특정 사용자가 관리자인지 확인
     */
    @Query("SELECT u.isAdmin FROM User u WHERE u.id = :userId")
    Optional<Boolean> isUserAdmin(@Param("userId") String userId);

    /**
     * 사용자의 마지막 로그인 시간 업데이트
     */
    @Query("UPDATE User u SET u.lastLoginAt = :loginTime, u.updatedAt = :updateTime WHERE u.id = :userId")
    void updateLastLoginAt(@Param("userId") String userId,
                           @Param("loginTime") LocalDateTime loginTime,
                           @Param("updateTime") LocalDateTime updateTime);

    /**
     * 로그인 시도 횟수 증가
     */
    @Query("UPDATE User u SET u.loginAttempts = u.loginAttempts + 1, u.updatedAt = :updateTime WHERE u.id = :userId")
    void incrementLoginAttempts(@Param("userId") String userId, @Param("updateTime") LocalDateTime updateTime);

    /**
     * 계정 잠금 설정
     */
    @Query("UPDATE User u SET u.isLocked = true, u.lockedUntil = :lockUntil, u.updatedAt = :updateTime WHERE u.id = :userId")
    void lockUser(@Param("userId") String userId,
                  @Param("lockUntil") LocalDateTime lockUntil,
                  @Param("updateTime") LocalDateTime updateTime);

    /**
     * 계정 잠금 해제
     */
    @Query("UPDATE User u SET u.isLocked = false, u.loginAttempts = 0, u.lockedUntil = null, u.updatedAt = :updateTime WHERE u.id = :userId")
    void unlockUser(@Param("userId") String userId, @Param("updateTime") LocalDateTime updateTime);

    /**
     * 사용자 비활성화
     */
    @Query("UPDATE User u SET u.isActive = false, u.updatedAt = :updateTime WHERE u.id = :userId")
    void deactivateUser(@Param("userId") String userId, @Param("updateTime") LocalDateTime updateTime);

    /**
     * 사용자 활성화
     */
    @Query("UPDATE User u SET u.isActive = true, u.updatedAt = :updateTime WHERE u.id = :userId")
    void activateUser(@Param("userId") String userId, @Param("updateTime") LocalDateTime updateTime);

    /**
     * 프로필 이미지 경로 업데이트
     */
    @Query("UPDATE User u SET u.profileImagePath = :imagePath, u.updatedAt = :updateTime WHERE u.id = :userId")
    void updateProfileImagePath(@Param("userId") String userId,
                                @Param("imagePath") String imagePath,
                                @Param("updateTime") LocalDateTime updateTime);

    /**
     * 알림 설정 업데이트
     */
    @Query("UPDATE User u SET u.inspectionReminder = :inspectionReminder, " +
            "u.complaintUpdates = :complaintUpdates, " +
            "u.systemNotifications = :systemNotifications, " +
            "u.emailNotifications = :emailNotifications, " +
            "u.updatedAt = :updateTime WHERE u.id = :userId")
    void updateNotificationSettings(@Param("userId") String userId,
                                    @Param("inspectionReminder") Boolean inspectionReminder,
                                    @Param("complaintUpdates") Boolean complaintUpdates,
                                    @Param("systemNotifications") Boolean systemNotifications,
                                    @Param("emailNotifications") Boolean emailNotifications,
                                    @Param("updateTime") LocalDateTime updateTime);
}