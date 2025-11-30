package com.dormitory.SpringBoot.services;

import com.dormitory.SpringBoot.domain.AdminCode;
import com.dormitory.SpringBoot.repository.AdminCodeRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import jakarta.annotation.PostConstruct;
import java.util.List;
import java.util.Optional;

/**
 * 관리자 코드 서비스
 */
@Service
@Transactional
public class AdminCodeService {

    private static final Logger logger = LoggerFactory.getLogger(AdminCodeService.class);

    // 기본 관리자 코드
    private static final String DEFAULT_ADMIN_CODE = "hanbat2025";
    private static final String DEFAULT_ADMIN_CODE_DESC = "기본 관리자 코드";

    @Autowired
    private AdminCodeRepository adminCodeRepository;

    /**
     * 애플리케이션 시작 시 기본 관리자 코드 생성
     */
    @PostConstruct
    public void initDefaultAdminCode() {
        try {
            if (!adminCodeRepository.existsByCode(DEFAULT_ADMIN_CODE)) {
                AdminCode defaultCode = new AdminCode();
                defaultCode.setCode(DEFAULT_ADMIN_CODE);
                defaultCode.setDescription(DEFAULT_ADMIN_CODE_DESC);
                defaultCode.setIsActive(true);
                defaultCode.setCreatedBy("SYSTEM");
                adminCodeRepository.save(defaultCode);
                logger.info("기본 관리자 코드 생성 완료: {}", DEFAULT_ADMIN_CODE);
            } else {
                logger.info("기본 관리자 코드가 이미 존재합니다.");
            }
        } catch (Exception e) {
            logger.error("기본 관리자 코드 생성 실패", e);
        }
    }

    /**
     * 관리자 코드 검증
     */
    public boolean validateAdminCode(String code) {
        if (code == null || code.trim().isEmpty()) {
            logger.warn("관리자 코드 검증 실패: 코드가 비어있음");
            return false;
        }

        boolean isValid = adminCodeRepository.existsByCodeAndIsActiveTrue(code.trim());
        logger.info("관리자 코드 검증 - 코드: {}, 결과: {}", code, isValid ? "유효" : "무효");
        return isValid;
    }

    /**
     * 관리자 코드 사용 기록 (회원가입 성공 시 호출)
     */
    public void recordCodeUsage(String code) {
        try {
            Optional<AdminCode> adminCodeOpt = adminCodeRepository.findByCode(code);
            if (adminCodeOpt.isPresent()) {
                AdminCode adminCode = adminCodeOpt.get();
                adminCode.incrementUseCount();
                adminCodeRepository.save(adminCode);
                logger.info("관리자 코드 사용 기록 - 코드: {}, 사용 횟수: {}", code, adminCode.getUseCount());
            }
        } catch (Exception e) {
            logger.warn("관리자 코드 사용 기록 실패: {}", e.getMessage());
        }
    }

    /**
     * 모든 관리자 코드 조회 (관리자용)
     */
    @Transactional(readOnly = true)
    public List<AdminCode> getAllCodes() {
        return adminCodeRepository.findAllByOrderByCreatedAtDesc();
    }

    /**
     * 활성화된 코드만 조회
     */
    @Transactional(readOnly = true)
    public List<AdminCode> getActiveCodes() {
        return adminCodeRepository.findByIsActiveTrueOrderByCreatedAtDesc();
    }

    /**
     * 관리자 코드 생성
     */
    public AdminCode createCode(String code, String description, String createdBy) {
        logger.info("관리자 코드 생성 - 코드: {}", code);

        if (adminCodeRepository.existsByCode(code)) {
            throw new RuntimeException("이미 존재하는 코드입니다: " + code);
        }

        AdminCode adminCode = new AdminCode();
        adminCode.setCode(code);
        adminCode.setDescription(description);
        adminCode.setIsActive(true);
        adminCode.setCreatedBy(createdBy);

        AdminCode saved = adminCodeRepository.save(adminCode);
        logger.info("관리자 코드 생성 완료 - ID: {}", saved.getId());
        return saved;
    }

    /**
     * 관리자 코드 수정
     */
    public AdminCode updateCode(Long id, String newCode, String description, Boolean isActive) {
        logger.info("관리자 코드 수정 - ID: {}", id);

        AdminCode adminCode = adminCodeRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("코드를 찾을 수 없습니다: " + id));

        // 코드 변경 시 중복 체크
        if (newCode != null && !newCode.equals(adminCode.getCode())) {
            if (adminCodeRepository.existsByCode(newCode)) {
                throw new RuntimeException("이미 존재하는 코드입니다: " + newCode);
            }
            adminCode.setCode(newCode);
        }

        if (description != null) {
            adminCode.setDescription(description);
        }

        if (isActive != null) {
            adminCode.setIsActive(isActive);
        }

        AdminCode updated = adminCodeRepository.save(adminCode);
        logger.info("관리자 코드 수정 완료 - ID: {}", id);
        return updated;
    }

    /**
     * 관리자 코드 삭제
     */
    public void deleteCode(Long id) {
        logger.info("관리자 코드 삭제 - ID: {}", id);

        AdminCode adminCode = adminCodeRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("코드를 찾을 수 없습니다: " + id));

        // 기본 코드는 삭제 불가
        if (DEFAULT_ADMIN_CODE.equals(adminCode.getCode())) {
            throw new RuntimeException("기본 관리자 코드는 삭제할 수 없습니다.");
        }

        adminCodeRepository.delete(adminCode);
        logger.info("관리자 코드 삭제 완료 - ID: {}", id);
    }

    /**
     * 관리자 코드 활성화/비활성화 토글
     */
    public AdminCode toggleCode(Long id) {
        logger.info("관리자 코드 토글 - ID: {}", id);

        AdminCode adminCode = adminCodeRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("코드를 찾을 수 없습니다: " + id));

        adminCode.setIsActive(!Boolean.TRUE.equals(adminCode.getIsActive()));
        AdminCode updated = adminCodeRepository.save(adminCode);

        logger.info("관리자 코드 토글 완료 - ID: {}, 활성화: {}", id, updated.getIsActive());
        return updated;
    }
}
