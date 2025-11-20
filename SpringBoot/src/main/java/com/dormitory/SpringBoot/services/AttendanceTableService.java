package com.dormitory.SpringBoot.services;

import com.dormitory.SpringBoot.domain.AttendanceTable;
import com.dormitory.SpringBoot.domain.User;
import com.dormitory.SpringBoot.dto.AttendanceRequest;
import com.dormitory.SpringBoot.repository.AttendanceTableRepository;
import com.dormitory.SpringBoot.repository.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;
import java.util.stream.Collectors;

/**
 * 점호 출석 테이블 관리 서비스
 */
@Service
@Transactional
public class AttendanceTableService {

    private static final Logger logger = LoggerFactory.getLogger(AttendanceTableService.class);

    @Autowired
    private AttendanceTableRepository attendanceTableRepository;

    @Autowired
    private UserRepository userRepository;

    /**
     * 특정 날짜의 출석 테이블 생성
     * 모든 활성 사용자에 대해 출석 항목 자동 생성
     */
    public AttendanceRequest.AttendanceTableResponse createAttendanceTable(LocalDate inspectionDate) {
        logger.info("출석 테이블 생성 시작 - 날짜: {}", inspectionDate);

        try {
            // 이미 해당 날짜의 테이블이 존재하는지 확인
            if (attendanceTableRepository.existsByInspectionDate(inspectionDate)) {
                logger.warn("이미 존재하는 출석 테이블 - 날짜: {}", inspectionDate);
                throw new RuntimeException("해당 날짜의 출석 테이블이 이미 존재합니다.");
            }

            // 모든 활성 사용자 조회
            List<User> activeUsers = userRepository.findByIsActiveTrue();
            logger.info("활성 사용자 수: {}", activeUsers.size());

            // 각 사용자에 대해 출석 항목 생성
            List<AttendanceTable> attendanceEntries = activeUsers.stream()
                .map(user -> new AttendanceTable(
                    inspectionDate,
                    user.getRoomNumber(),
                    user.getId(),
                    user.getName()
                ))
                .collect(Collectors.toList());

            // 데이터베이스에 저장
            attendanceTableRepository.saveAll(attendanceEntries);
            logger.info("출석 테이블 생성 완료 - 항목 수: {}", attendanceEntries.size());

            // 생성된 테이블 조회 및 반환
            return getAttendanceTable(inspectionDate);

        } catch (Exception e) {
            logger.error("출석 테이블 생성 실패 - 날짜: {}, 오류: {}", inspectionDate, e.getMessage());
            throw new RuntimeException("출석 테이블 생성 중 오류가 발생했습니다: " + e.getMessage());
        }
    }

    /**
     * 특정 날짜의 출석 테이블 조회
     */
    public AttendanceRequest.AttendanceTableResponse getAttendanceTable(LocalDate inspectionDate) {
        logger.info("출석 테이블 조회 - 날짜: {}", inspectionDate);

        List<AttendanceTable> entries = attendanceTableRepository
            .findByInspectionDateOrderByRoomNumberAsc(inspectionDate);

        // DTO로 변환
        List<AttendanceRequest.AttendanceEntryResponse> entryResponses = entries.stream()
            .map(this::convertToEntryResponse)
            .collect(Collectors.toList());

        // 통계 계산
        AttendanceRequest.AttendanceStatistics statistics = calculateStatistics(entries);

        return new AttendanceRequest.AttendanceTableResponse(
            inspectionDate,
            entryResponses,
            statistics
        );
    }

    /**
     * 출석 항목 수정
     */
    public AttendanceRequest.AttendanceEntryResponse updateAttendanceEntry(
            Long entryId, 
            AttendanceRequest.UpdateEntryRequest request) {
        
        logger.info("출석 항목 수정 시작 - ID: {}", entryId);

        AttendanceTable entry = attendanceTableRepository.findById(entryId)
            .orElseThrow(() -> new RuntimeException("출석 항목을 찾을 수 없습니다."));

        // 수정 사항 적용
        if (request.getIsSubmitted() != null) {
            entry.setIsSubmitted(request.getIsSubmitted());
        }
        if (request.getScore() != null) {
            entry.setScore(request.getScore());
        }
        if (request.getStatus() != null) {
            entry.setStatus(request.getStatus());
        }
        if (request.getNotes() != null) {
            entry.setNotes(request.getNotes());
        }

        AttendanceTable updated = attendanceTableRepository.save(entry);
        logger.info("출석 항목 수정 완료 - ID: {}", entryId);

        return convertToEntryResponse(updated);
    }

    /**
     * 특정 날짜의 출석 테이블 삭제
     */
    public void deleteAttendanceTable(LocalDate inspectionDate) {
        logger.info("출석 테이블 삭제 시작 - 날짜: {}", inspectionDate);

        if (!attendanceTableRepository.existsByInspectionDate(inspectionDate)) {
            throw new RuntimeException("해당 날짜의 출석 테이블이 존재하지 않습니다.");
        }

        attendanceTableRepository.deleteByInspectionDate(inspectionDate);
        logger.info("출석 테이블 삭제 완료 - 날짜: {}", inspectionDate);
    }

    /**
     * 점호 제출 시 출석 테이블 업데이트
     * (InspectionService에서 호출)
     */
    public void updateAttendanceOnInspectionSubmit(
            String userId, 
            LocalDate inspectionDate, 
            Integer score, 
            String status) {
        
        logger.info("점호 제출에 따른 출석 업데이트 - 사용자: {}, 날짜: {}", userId, inspectionDate);

        attendanceTableRepository.findByInspectionDateAndUserId(inspectionDate, userId)
            .ifPresent(entry -> {
                entry.markAsSubmitted(score, status);
                attendanceTableRepository.save(entry);
                logger.info("출석 상태 업데이트 완료 - 사용자: {}", userId);
            });
    }

    /**
     * Entity를 DTO로 변환
     */
    private AttendanceRequest.AttendanceEntryResponse convertToEntryResponse(AttendanceTable entry) {
        return new AttendanceRequest.AttendanceEntryResponse(
            entry.getId(),
            entry.getInspectionDate(),
            entry.getRoomNumber(),
            entry.getUserId(),
            entry.getUserName(),
            entry.getIsSubmitted(),
            entry.getSubmissionTime(),
            entry.getScore(),
            entry.getStatus(),
            entry.getNotes()
        );
    }

    /**
     * 통계 계산
     */
    private AttendanceRequest.AttendanceStatistics calculateStatistics(List<AttendanceTable> entries) {
        long totalRooms = entries.size();
        long submittedRooms = entries.stream()
            .filter(AttendanceTable::getIsSubmitted)
            .count();
        long pendingRooms = totalRooms - submittedRooms;
        double submissionRate = totalRooms > 0 ? (submittedRooms * 100.0 / totalRooms) : 0.0;

        return new AttendanceRequest.AttendanceStatistics(
            totalRooms,
            submittedRooms,
            pendingRooms,
            submissionRate
        );
    }
}
