package com.dormitory.SpringBoot.repository;

import com.dormitory.SpringBoot.domain.AdminCode;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

/**
 * 관리자 코드 Repository
 */
@Repository
public interface AdminCodeRepository extends JpaRepository<AdminCode, Long> {

    /**
     * 코드로 조회
     */
    Optional<AdminCode> findByCode(String code);

    /**
     * 활성화된 코드로 조회
     */
    @Query("SELECT a FROM AdminCode a WHERE a.code = :code AND a.isActive = true")
    Optional<AdminCode> findByCodeAndIsActiveTrue(String code);

    /**
     * 코드 존재 여부 확인
     */
    boolean existsByCode(String code);

    /**
     * 활성화된 코드 존재 여부 확인
     */
    @Query("SELECT COUNT(a) > 0 FROM AdminCode a WHERE a.code = :code AND a.isActive = true")
    boolean existsByCodeAndIsActiveTrue(String code);

    /**
     * 모든 코드 조회 (생성일 역순)
     */
    List<AdminCode> findAllByOrderByCreatedAtDesc();

    /**
     * 활성화된 코드만 조회
     */
    List<AdminCode> findByIsActiveTrueOrderByCreatedAtDesc();
}
