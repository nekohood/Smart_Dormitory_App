package com.dormitory.SpringBoot.services;

import com.dormitory.SpringBoot.domain.AllowedUser;
import com.dormitory.SpringBoot.domain.User;
import com.dormitory.SpringBoot.dto.AllowedUserRequest;
import com.dormitory.SpringBoot.repository.AllowedUserRepository;
import com.dormitory.SpringBoot.repository.UserRepository;
import org.apache.poi.ss.usermodel.*;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

/**
 * 허용된 사용자 관리 서비스
 * ✅ 수정: CRUD 완전 지원 (Update 기능 추가)
 * ✅ 수정: 등록된 사용자도 수정/삭제 가능
 * ✅ 추가: 등록된 사용자 정보 수정 시 User 테이블도 자동 업데이트
 * ✅ 필수 필드: 학번, 이름, 기숙사명, 호실번호
 */
@Service
@Transactional
public class AllowedUserService {

    private static final Logger logger = LoggerFactory.getLogger(AllowedUserService.class);

    @Autowired
    private AllowedUserRepository allowedUserRepository;

    @Autowired
    private UserRepository userRepository;

    /**
     * 엑셀 파일로부터 허용 사용자 목록 업로드
     *
     * ✅ 엑셀 형식:
     * - 필수: 학번(A) | 이름(B) | 기숙사명(C) | 호실번호(D)
     * - 선택: 전화번호(E) | 이메일(F)
     */
    public AllowedUserRequest.UploadResponse uploadAllowedUsersFromExcel(MultipartFile file) {
        logger.info("엑셀 파일 업로드 시작 - 파일명: {}", file.getOriginalFilename());

        int totalCount = 0;
        int successCount = 0;
        int failCount = 0;
        List<String> errors = new ArrayList<>();

        try (Workbook workbook = new XSSFWorkbook(file.getInputStream())) {
            Sheet sheet = workbook.getSheetAt(0);

            // 첫 번째 행은 헤더이므로 건너뜀
            for (int i = 1; i <= sheet.getLastRowNum(); i++) {
                Row row = sheet.getRow(i);
                if (row == null) continue;

                totalCount++;

                try {
                    // 엑셀에서 데이터 읽기 (컬럼 순서)
                    // 필수: 학번(A), 이름(B), 기숙사명(C), 호실번호(D)
                    // 선택: 전화번호(E), 이메일(F)
                    String userId = getCellValueAsString(row.getCell(0));           // A: 학번 (필수)
                    String name = getCellValueAsString(row.getCell(1));             // B: 이름 (필수)
                    String dormitoryBuilding = getCellValueAsString(row.getCell(2)); // C: 기숙사명 (필수)
                    String roomNumber = getCellValueAsString(row.getCell(3));       // D: 호실번호 (필수)
                    String phoneNumber = getCellValueAsString(row.getCell(4));      // E: 전화번호 (선택)
                    String email = getCellValueAsString(row.getCell(5));            // F: 이메일 (선택)

                    // 필수 필드 검증 (4개 모두 필수)
                    if (userId == null || userId.trim().isEmpty()) {
                        errors.add("행 " + (i + 1) + ": 학번이 비어있습니다.");
                        failCount++;
                        continue;
                    }

                    if (name == null || name.trim().isEmpty()) {
                        errors.add("행 " + (i + 1) + ": 이름이 비어있습니다.");
                        failCount++;
                        continue;
                    }

                    if (dormitoryBuilding == null || dormitoryBuilding.trim().isEmpty()) {
                        errors.add("행 " + (i + 1) + ": 기숙사명이 비어있습니다.");
                        failCount++;
                        continue;
                    }

                    if (roomNumber == null || roomNumber.trim().isEmpty()) {
                        errors.add("행 " + (i + 1) + ": 호실번호가 비어있습니다.");
                        failCount++;
                        continue;
                    }

                    // 중복 확인
                    if (allowedUserRepository.existsByUserId(userId.trim())) {
                        errors.add("행 " + (i + 1) + ": 이미 등록된 학번입니다 (" + userId + ")");
                        failCount++;
                        continue;
                    }

                    // 사용자 생성 및 저장
                    AllowedUser allowedUser = new AllowedUser(
                            userId.trim(),
                            name.trim(),
                            dormitoryBuilding.trim(),
                            roomNumber.trim(),
                            phoneNumber != null ? phoneNumber.trim() : null,
                            email != null ? email.trim() : null
                    );

                    allowedUserRepository.save(allowedUser);
                    successCount++;
                    logger.debug("허용 사용자 추가 성공 - 학번: {}, 이름: {}, 기숙사: {}, 호실: {}",
                            userId, name, dormitoryBuilding, roomNumber);

                } catch (Exception e) {
                    errors.add("행 " + (i + 1) + ": " + e.getMessage());
                    failCount++;
                    logger.error("행 {} 처리 중 오류 발생: {}", i + 1, e.getMessage());
                }
            }

            logger.info("엑셀 업로드 완료 - 전체: {}, 성공: {}, 실패: {}", totalCount, successCount, failCount);

        } catch (IOException e) {
            logger.error("엑셀 파일 읽기 실패: {}", e.getMessage());
            throw new RuntimeException("엑셀 파일을 읽을 수 없습니다: " + e.getMessage());
        }

        return new AllowedUserRequest.UploadResponse(totalCount, successCount, failCount, errors);
    }

    /**
     * 개별 사용자 추가
     * ✅ 필수 필드: 학번, 이름, 기숙사명, 호실번호
     */
    public AllowedUserRequest.AllowedUserResponse addAllowedUser(AllowedUserRequest.AddUserRequest request) {
        logger.info("허용 사용자 추가 - 학번: {}", request.getUserId());

        // 필수 필드 검증
        if (request.getUserId() == null || request.getUserId().trim().isEmpty()) {
            throw new RuntimeException("학번은 필수입니다.");
        }
        if (request.getName() == null || request.getName().trim().isEmpty()) {
            throw new RuntimeException("이름은 필수입니다.");
        }
        if (request.getDormitoryBuilding() == null || request.getDormitoryBuilding().trim().isEmpty()) {
            throw new RuntimeException("기숙사명은 필수입니다.");
        }
        if (request.getRoomNumber() == null || request.getRoomNumber().trim().isEmpty()) {
            throw new RuntimeException("호실번호는 필수입니다.");
        }

        // 중복 확인
        if (allowedUserRepository.existsByUserId(request.getUserId())) {
            throw new RuntimeException("이미 등록된 학번입니다: " + request.getUserId());
        }

        AllowedUser allowedUser = new AllowedUser(
                request.getUserId(),
                request.getName(),
                request.getDormitoryBuilding(),
                request.getRoomNumber(),
                request.getPhoneNumber(),
                request.getEmail()
        );

        AllowedUser saved = allowedUserRepository.save(allowedUser);
        logger.info("허용 사용자 추가 완료 - 학번: {}, 기숙사: {}, 호실: {}",
                request.getUserId(), request.getDormitoryBuilding(), request.getRoomNumber());

        return convertToResponse(saved);
    }

    /**
     * ✅ 허용 사용자 정보 수정
     * ✅ 등록된 사용자도 수정 가능
     * ✅ 추가: 등록된 사용자인 경우 User 테이블도 자동 업데이트
     */
    public AllowedUserRequest.AllowedUserResponse updateAllowedUser(
            String userId, AllowedUserRequest.UpdateUserRequest request) {

        logger.info("허용 사용자 수정 - 학번: {}", userId);

        AllowedUser allowedUser = allowedUserRepository.findByUserId(userId)
                .orElseThrow(() -> new RuntimeException("허용되지 않은 사용자입니다: " + userId));

        // 수정 가능한 필드 업데이트 (null이 아닌 경우만)
        if (request.getName() != null && !request.getName().trim().isEmpty()) {
            allowedUser.setName(request.getName().trim());
        }
        if (request.getDormitoryBuilding() != null && !request.getDormitoryBuilding().trim().isEmpty()) {
            allowedUser.setDormitoryBuilding(request.getDormitoryBuilding().trim());
        }
        if (request.getRoomNumber() != null && !request.getRoomNumber().trim().isEmpty()) {
            allowedUser.setRoomNumber(request.getRoomNumber().trim());
        }
        // phoneNumber와 email은 빈 문자열도 허용 (null일 때만 무시)
        if (request.getPhoneNumber() != null) {
            allowedUser.setPhoneNumber(request.getPhoneNumber().trim().isEmpty() ? null : request.getPhoneNumber().trim());
        }
        if (request.getEmail() != null) {
            allowedUser.setEmail(request.getEmail().trim().isEmpty() ? null : request.getEmail().trim());
        }

        AllowedUser saved = allowedUserRepository.save(allowedUser);

        // ✅ 등록된 사용자인 경우 User 테이블도 업데이트
        if (Boolean.TRUE.equals(allowedUser.getIsRegistered())) {
            updateRegisteredUser(userId, request);
        }

        logger.info("허용 사용자 수정 완료 - 학번: {}, 등록상태: {}", userId, allowedUser.getIsRegistered() ? "등록됨" : "미등록");

        return convertToResponse(saved);
    }

    /**
     * ✅ 등록된 사용자의 User 테이블 정보 업데이트
     * - 관리자가 AllowedUser 수정 시 자동으로 User 테이블도 업데이트
     */
    private void updateRegisteredUser(String userId, AllowedUserRequest.UpdateUserRequest request) {
        try {
            Optional<User> userOptional = userRepository.findById(userId);

            if (userOptional.isPresent()) {
                User user = userOptional.get();
                boolean updated = false;

                // 이름 업데이트
                if (request.getName() != null && !request.getName().trim().isEmpty()) {
                    user.setName(request.getName().trim());
                    updated = true;
                }

                // 기숙사 업데이트
                if (request.getDormitoryBuilding() != null && !request.getDormitoryBuilding().trim().isEmpty()) {
                    user.setDormitoryBuilding(request.getDormitoryBuilding().trim());
                    updated = true;
                }

                // 호실 업데이트
                if (request.getRoomNumber() != null && !request.getRoomNumber().trim().isEmpty()) {
                    user.setRoomNumber(request.getRoomNumber().trim());
                    updated = true;
                }

                // 전화번호 업데이트
                if (request.getPhoneNumber() != null) {
                    user.setPhoneNumber(request.getPhoneNumber().trim().isEmpty() ? null : request.getPhoneNumber().trim());
                    updated = true;
                }

                // 이메일 업데이트
                if (request.getEmail() != null) {
                    user.setEmail(request.getEmail().trim().isEmpty() ? null : request.getEmail().trim());
                    updated = true;
                }

                if (updated) {
                    user.setUpdatedAt(LocalDateTime.now());
                    userRepository.save(user);
                    logger.info("등록된 사용자 정보 자동 업데이트 완료 - 학번: {}", userId);
                }
            } else {
                logger.warn("등록된 사용자이지만 User 테이블에서 찾을 수 없음 - 학번: {}", userId);
            }
        } catch (Exception e) {
            logger.error("등록된 사용자 정보 업데이트 중 오류 발생 - 학번: {}, 오류: {}", userId, e.getMessage());
            // User 테이블 업데이트 실패해도 AllowedUser 업데이트는 유지
        }
    }

    /**
     * 허용 사용자 목록 조회
     */
    @Transactional(readOnly = true)
    public AllowedUserRequest.AllowedUserListResponse getAllAllowedUsers() {
        logger.info("허용 사용자 목록 조회");

        List<AllowedUser> users = allowedUserRepository.findAll();

        List<AllowedUserRequest.AllowedUserResponse> responses = users.stream()
                .map(this::convertToResponse)
                .collect(Collectors.toList());

        long totalCount = allowedUserRepository.count();
        long registeredCount = allowedUserRepository.countByIsRegisteredTrue();
        long unregisteredCount = allowedUserRepository.countByIsRegisteredFalse();

        logger.info("허용 사용자 목록 조회 완료 - 전체: {}, 가입완료: {}, 미가입: {}",
                totalCount, registeredCount, unregisteredCount);

        return new AllowedUserRequest.AllowedUserListResponse(
                responses,
                totalCount,
                registeredCount,
                unregisteredCount
        );
    }

    /**
     * 특정 학번의 허용 사용자 조회
     */
    @Transactional(readOnly = true)
    public AllowedUserRequest.AllowedUserResponse getAllowedUser(String userId) {
        AllowedUser user = allowedUserRepository.findByUserId(userId)
                .orElseThrow(() -> new RuntimeException("허용되지 않은 사용자입니다: " + userId));

        return convertToResponse(user);
    }

    /**
     * 학번으로 허용 여부 확인
     */
    @Transactional(readOnly = true)
    public boolean isUserAllowed(String userId) {
        boolean allowed = allowedUserRepository.existsByUserId(userId);
        logger.debug("허용 사용자 확인 - 학번: {}, 결과: {}", userId, allowed ? "허용" : "미허용");
        return allowed;
    }

    /**
     * 회원가입 완료 시 상태 업데이트
     */
    public void markAsRegistered(String userId) {
        logger.info("허용 사용자 가입 완료 처리 - 학번: {}", userId);

        AllowedUser user = allowedUserRepository.findByUserId(userId)
                .orElseThrow(() -> new RuntimeException("허용되지 않은 사용자입니다: " + userId));

        user.markAsRegistered();
        allowedUserRepository.save(user);

        logger.info("허용 사용자 가입 완료 처리 완료 - 학번: {}", userId);
    }

    /**
     * ✅ 허용 사용자 삭제
     * ✅ 수정: 등록된 사용자도 삭제 가능
     */
    public void deleteAllowedUser(String userId) {
        logger.info("허용 사용자 삭제 - 학번: {}", userId);

        AllowedUser user = allowedUserRepository.findByUserId(userId)
                .orElseThrow(() -> new RuntimeException("허용되지 않은 사용자입니다: " + userId));

        // ✅ 등록 여부와 관계없이 삭제 가능
        boolean wasRegistered = user.getIsRegistered();

        allowedUserRepository.delete(user);
        logger.info("허용 사용자 삭제 완료 - 학번: {}, 기존등록상태: {}", userId, wasRegistered ? "등록됨" : "미등록");
    }

    /**
     * Entity를 DTO로 변환
     */
    private AllowedUserRequest.AllowedUserResponse convertToResponse(AllowedUser user) {
        return new AllowedUserRequest.AllowedUserResponse(
                user.getId(),
                user.getUserId(),
                user.getName(),
                user.getDormitoryBuilding(),
                user.getRoomNumber(),
                user.getPhoneNumber(),
                user.getEmail(),
                user.getIsRegistered(),
                user.getRegisteredAt(),
                user.getCreatedAt()
        );
    }

    /**
     * 엑셀 셀 값을 문자열로 변환
     */
    private String getCellValueAsString(Cell cell) {
        if (cell == null) return null;

        switch (cell.getCellType()) {
            case STRING:
                return cell.getStringCellValue();
            case NUMERIC:
                // 숫자를 문자열로 변환 (학번, 호실번호 등)
                double numericValue = cell.getNumericCellValue();
                // 정수인 경우 소수점 제거
                if (numericValue == Math.floor(numericValue)) {
                    return String.valueOf((long) numericValue);
                }
                return String.valueOf(numericValue);
            case BOOLEAN:
                return String.valueOf(cell.getBooleanCellValue());
            case FORMULA:
                try {
                    return cell.getStringCellValue();
                } catch (Exception e) {
                    try {
                        return String.valueOf((long) cell.getNumericCellValue());
                    } catch (Exception ex) {
                        return null;
                    }
                }
            case BLANK:
                return null;
            default:
                return null;
        }
    }
}