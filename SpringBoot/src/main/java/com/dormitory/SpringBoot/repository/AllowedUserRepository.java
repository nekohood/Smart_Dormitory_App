package com.dormitory.SpringBoot.repository;

import com.dormitory.SpringBoot.domain.AllowedUser;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

/**
 * 허용된 사용자 목록에 대한 데이터베이스 접근을 담당하는 Repository
 */
@Repository
public interface AllowedUserRepository extends JpaRepository<AllowedUser, Long> {

    /**
     * 사용자 ID로 허용된 사용자 조회
     */
    Optional<AllowedUser> findByUserId(String userId);

    /**
     * 사용자 ID 존재 여부 확인
     */
    boolean existsByUserId(String userId);

    /**
     * 등록 여부로 사용자 조회
     */
    List<AllowedUser> findByIsRegistered(Boolean isRegistered);

    /**
     * 등록되지 않은 사용자 목록 조회
     */
    List<AllowedUser> findByIsRegisteredFalse();

    /**
     * 등록된 사용자 목록 조회
     */
    List<AllowedUser> findByIsRegisteredTrue();

    /**
     * 방 번호로 사용자 조회
     */
    List<AllowedUser> findByRoomNumber(String roomNumber);

    /**
     * 이름으로 사용자 조회
     */
    List<AllowedUser> findByName(String name);

    /**
     * 전체 허용된 사용자 수
     */
    long count();

    /**
     * 등록 완료된 사용자 수
     */
    long countByIsRegisteredTrue();

    /**
     * 미등록 사용자 수
     */
    long countByIsRegisteredFalse();
}
