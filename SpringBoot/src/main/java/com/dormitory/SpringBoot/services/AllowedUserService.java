package com.dormitory.SpringBoot.services;

import com.dormitory.SpringBoot.domain.AllowedUser;
import com.dormitory.SpringBoot.dto.AllowedUserRequest;
import com.dormitory.SpringBoot.repository.AllowedUserRepository;
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
import java.util.stream.Collectors;

/**
 * 허용된 사용자 관리 서비스
 */
@Service
@Transactional
public class AllowedUserService {

    private static final Logger logger = LoggerFactory.getLogger(AllowedUserService.class);

    @Autowired
    private AllowedUserRepository allowedUserRepository;

    /**
     * 엑셀 파일로부터 허용 사용자 목록 업로드
     * 예상 엑셀 형식: 학번(userId) | 이름 | 호실 | 전화번호 | 이메일
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
                    // 엑셀에서 데이터 읽기
                    String userId = getCellValueAsString(row.getCell(0));
                    String name = getCellValueAsString(row.getCell(1));
                    String roomNumber = getCellValueAsString(row.getCell(2));
                    String phoneNumber = getCellValueAsString(row.getCell(3));
                    String email = getCellValueAsString(row.getCell(4));

                    // 필수 필드 검증
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

                    // 중복 확인
                    if (allowedUserRepository.existsByUserId(userId)) {
                        errors.add("행 " + (i + 1) + ": 이미 등록된 학번입니다 - " + userId);
                        failCount++;
                        continue;
                    }

                    // AllowedUser 생성 및 저장
                    AllowedUser allowedUser = new AllowedUser(
                        userId.trim(),
                        name.trim(),
                        roomNumber != null ? roomNumber.trim() : null,
                        phoneNumber != null ? phoneNumber.trim() : null,
                        email != null ? email.trim() : null
                    );

                    allowedUserRepository.save(allowedUser);
                    successCount++;

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
     */
    public AllowedUserRequest.AllowedUserResponse addAllowedUser(AllowedUserRequest.AddUserRequest request) {
        logger.info("허용 사용자 추가 - 학번: {}", request.getUserId());

        // 중복 확인
        if (allowedUserRepository.existsByUserId(request.getUserId())) {
            throw new RuntimeException("이미 등록된 학번입니다: " + request.getUserId());
        }

        AllowedUser allowedUser = new AllowedUser(
            request.getUserId(),
            request.getName(),
            request.getRoomNumber(),
            request.getPhoneNumber(),
            request.getEmail()
        );

        AllowedUser saved = allowedUserRepository.save(allowedUser);
        logger.info("허용 사용자 추가 완료 - 학번: {}", request.getUserId());

        return convertToResponse(saved);
    }

    /**
     * 허용 사용자 목록 조회
     */
    public AllowedUserRequest.AllowedUserListResponse getAllAllowedUsers() {
        List<AllowedUser> users = allowedUserRepository.findAll();
        
        List<AllowedUserRequest.AllowedUserResponse> userResponses = users.stream()
            .map(this::convertToResponse)
            .collect(Collectors.toList());

        long totalCount = allowedUserRepository.count();
        long registeredCount = allowedUserRepository.countByIsRegisteredTrue();
        long unregisteredCount = allowedUserRepository.countByIsRegisteredFalse();

        return new AllowedUserRequest.AllowedUserListResponse(
            userResponses,
            totalCount,
            registeredCount,
            unregisteredCount
        );
    }

    /**
     * 특정 학번의 허용 사용자 조회
     */
    public AllowedUserRequest.AllowedUserResponse getAllowedUser(String userId) {
        AllowedUser user = allowedUserRepository.findByUserId(userId)
            .orElseThrow(() -> new RuntimeException("허용되지 않은 사용자입니다: " + userId));
        
        return convertToResponse(user);
    }

    /**
     * 학번이 허용 목록에 있는지 확인
     */
    public boolean isUserAllowed(String userId) {
        return allowedUserRepository.existsByUserId(userId);
    }

    /**
     * 사용자 등록 완료 처리
     * (회원가입 시 호출)
     */
    public void markAsRegistered(String userId) {
        logger.info("사용자 등록 완료 처리 - 학번: {}", userId);

        AllowedUser user = allowedUserRepository.findByUserId(userId)
            .orElseThrow(() -> new RuntimeException("허용되지 않은 사용자입니다: " + userId));

        user.markAsRegistered();
        allowedUserRepository.save(user);
    }

    /**
     * 허용 사용자 삭제
     */
    public void deleteAllowedUser(String userId) {
        logger.info("허용 사용자 삭제 - 학번: {}", userId);

        AllowedUser user = allowedUserRepository.findByUserId(userId)
            .orElseThrow(() -> new RuntimeException("허용되지 않은 사용자입니다: " + userId));

        // 이미 등록된 사용자는 삭제 불가
        if (user.getIsRegistered()) {
            throw new RuntimeException("이미 등록된 사용자는 삭제할 수 없습니다: " + userId);
        }

        allowedUserRepository.delete(user);
        logger.info("허용 사용자 삭제 완료 - 학번: {}", userId);
    }

    /**
     * Entity를 DTO로 변환
     */
    private AllowedUserRequest.AllowedUserResponse convertToResponse(AllowedUser user) {
        return new AllowedUserRequest.AllowedUserResponse(
            user.getId(),
            user.getUserId(),
            user.getName(),
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
                // 숫자를 문자열로 변환 (학번 등)
                return String.valueOf((long) cell.getNumericCellValue());
            case BOOLEAN:
                return String.valueOf(cell.getBooleanCellValue());
            case FORMULA:
                return cell.getCellFormula();
            default:
                return null;
        }
    }
}
