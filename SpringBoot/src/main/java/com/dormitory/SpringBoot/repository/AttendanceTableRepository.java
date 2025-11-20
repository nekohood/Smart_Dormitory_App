package com.dormitory.SpringBoot.repository;

import com.dormitory.SpringBoot.domain.AttendanceTable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

/**
 * 점호 제출 상태 테이블에 대한 데이터베이스 접근을 담당하는 Repository
 */
@Repository
public interface AttendanceTableRepository extends JpaRepository<AttendanceTable, Long> {

    /**
     * 특정 날짜의 모든 점호 제출 상태 조회
     */
    List<AttendanceTable> findByInspectionDateOrderByRoomNumberAsc(LocalDate inspectionDate);

    /**
     * 특정 날짜와 호실의 점호 제출 상태 조회
     */
    Optional<AttendanceTable> findByInspectionDateAndRoomNumber(LocalDate inspectionDate, String roomNumber);

    /**
     * 특정 날짜와 사용자 ID의 점호 제출 상태 조회
     */
    Optional<AttendanceTable> findByInspectionDateAndUserId(LocalDate inspectionDate, String userId);

    /**
     * 특정 날짜의 제출 완료된 점호 수
     */
    long countByInspectionDateAndIsSubmittedTrue(LocalDate inspectionDate);

    /**
     * 특정 날짜의 미제출 점호 수
     */
    long countByInspectionDateAndIsSubmittedFalse(LocalDate inspectionDate);

    /**
     * 특정 날짜의 전체 점호 수
     */
    long countByInspectionDate(LocalDate inspectionDate);

    /**
     * 특정 날짜의 제출 상태별 점호 목록 조회
     */
    List<AttendanceTable> findByInspectionDateAndIsSubmitted(LocalDate inspectionDate, Boolean isSubmitted);

    /**
     * 특정 날짜의 점호 상태별 목록 조회
     */
    List<AttendanceTable> findByInspectionDateAndStatus(LocalDate inspectionDate, String status);

    /**
     * 특정 호실의 점호 이력 조회
     */
    List<AttendanceTable> findByRoomNumberOrderByInspectionDateDesc(String roomNumber);

    /**
     * 특정 사용자의 점호 이력 조회
     */
    List<AttendanceTable> findByUserIdOrderByInspectionDateDesc(String userId);

    /**
     * 특정 날짜 범위의 점호 제출 상태 조회
     */
    @Query("SELECT a FROM AttendanceTable a WHERE a.inspectionDate BETWEEN :startDate AND :endDate ORDER BY a.inspectionDate DESC, a.roomNumber ASC")
    List<AttendanceTable> findByInspectionDateBetween(@Param("startDate") LocalDate startDate, @Param("endDate") LocalDate endDate);

    /**
     * 특정 날짜의 점호 제출률 계산
     */
    @Query("SELECT (COUNT(a) * 100.0 / (SELECT COUNT(at) FROM AttendanceTable at WHERE at.inspectionDate = :date)) " +
           "FROM AttendanceTable a WHERE a.inspectionDate = :date AND a.isSubmitted = true")
    Double getSubmissionRateByDate(@Param("date") LocalDate date);

    /**
     * 특정 날짜에 테이블이 존재하는지 확인
     */
    boolean existsByInspectionDate(LocalDate inspectionDate);

    /**
     * 특정 날짜의 테이블 삭제
     */
    void deleteByInspectionDate(LocalDate inspectionDate);
}
