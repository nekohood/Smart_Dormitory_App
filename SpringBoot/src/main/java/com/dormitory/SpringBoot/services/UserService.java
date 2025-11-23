package com.dormitory.SpringBoot.services;

import com.dormitory.SpringBoot.domain.User;
import com.dormitory.SpringBoot.dto.LoginRequest;
import com.dormitory.SpringBoot.dto.RegisterRequest;
import com.dormitory.SpringBoot.dto.UpdateUserRequest;
import com.dormitory.SpringBoot.dto.UserResponse;
import com.dormitory.SpringBoot.repository.UserRepository;
import com.dormitory.SpringBoot.utils.EncryptionUtil;
import com.dormitory.SpringBoot.utils.JwtUtil;
import com.dormitory.SpringBoot.utils.SecurityUtils; // SecurityUtils 임포트
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

/**
 * 사용자 관련 비즈니스 로직 서비스 - 수정된 버전
 */
@Service
@Transactional
public class UserService {

    private static final Logger logger = LoggerFactory.getLogger(UserService.class);

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private JwtUtil jwtUtil;

    @Autowired
    private EncryptionUtil encryptionUtil;

    /**
     * 사용자 회원가입
     * 관리자 계정: 거주 동/방 번호 자동으로 "관리실" 설정
     * 일반 사용자: 입력받은 거주 동/방 번호 사용
     */
    public UserResponse register(RegisterRequest request) {
        try {
            logger.info("회원가입 처리 시작 - 사용자ID: {}, 관리자: {}", request.getId(), request.getIsAdmin());

            // 중복 체크
            if (userRepository.existsById(request.getId())) {
                throw new RuntimeException("이미 존재하는 사용자 ID입니다: " + request.getId());
            }

            // 이메일 중복 체크 (암호화 전 평문으로 체크)
            if (request.getEmail() != null && !request.getEmail().trim().isEmpty()) {
                String emailHash = SecurityUtils.hashUserId(request.getEmail().trim());
                if (userRepository.findByEmailHash(emailHash).isPresent()) {
                    throw new RuntimeException("이미 사용 중인 이메일입니다: " + request.getEmail());
                }
            }

            // 사용자 생성
            User user = new User();
            user.setId(request.getId());
            user.setPassword(passwordEncoder.encode(request.getPassword()));
            user.setIsAdmin(request.getIsAdmin() != null ? request.getIsAdmin() : false);
            user.setCreatedAt(LocalDateTime.now());
            user.setUpdatedAt(LocalDateTime.now());
            user.setIsActive(true);

            // ✅ 필수 필드: 이름 암호화 저장
            if (request.getName() != null && !request.getName().trim().isEmpty()) {
                user.setName(encryptionUtil.encrypt(request.getName()));
            }

            // ✅ 관리자 여부에 따라 거주 동/방 번호 설정
            if (Boolean.TRUE.equals(request.getIsAdmin())) {
                // 관리자는 자동으로 "관리실" 설정
                user.setDormitoryBuilding("관리실");
                user.setRoomNumber("관리실");
                logger.info("관리자 계정 - 거주 동/방 번호를 '관리실'로 자동 설정");
            } else {
                // 일반 사용자는 입력받은 값 사용 (필수)
                if (request.getDormitoryBuilding() != null && !request.getDormitoryBuilding().trim().isEmpty()) {
                    user.setDormitoryBuilding(request.getDormitoryBuilding());
                } else {
                    throw new RuntimeException("일반 사용자는 거주 동을 입력해야 합니다.");
                }

                if (request.getRoomNumber() != null && !request.getRoomNumber().trim().isEmpty()) {
                    user.setRoomNumber(request.getRoomNumber());
                } else {
                    throw new RuntimeException("일반 사용자는 방 번호를 입력해야 합니다.");
                }
            }

            // 선택 필드: 이메일
            if (request.getEmail() != null && !request.getEmail().trim().isEmpty()) {
                user.setEmail(encryptionUtil.encrypt(request.getEmail()));
                user.setEmailHash(SecurityUtils.hashUserId(request.getEmail().trim()));
            }

            // 선택 필드: 전화번호
            if (request.getPhoneNumber() != null && !request.getPhoneNumber().trim().isEmpty()) {
                user.setPhoneNumber(encryptionUtil.encrypt(request.getPhoneNumber()));
            }

            user = userRepository.save(user);
            logger.info("회원가입 완료 - 사용자ID: {}, 거주 동: {}, 방 번호: {}",
                    user.getId(), user.getDormitoryBuilding(), user.getRoomNumber());

            return convertToResponse(user);

        } catch (Exception e) {
            logger.error("회원가입 처리 중 오류 발생", e);
            throw new RuntimeException("회원가입에 실패했습니다: " + e.getMessage());
        }
    }

    /**
     * 사용자 로그인 - 수정된 메서드명 사용
     */
    public String login(LoginRequest request) {
        try {
            logger.info("로그인 처리 시작 - 사용자ID: {}", request.getId());

            // 사용자 조회
            User user = userRepository.findById(request.getId())
                    .orElseThrow(() -> new RuntimeException("존재하지 않는 사용자입니다."));

            // 계정 활성화 상태 확인
            if (!Boolean.TRUE.equals(user.getIsActive())) {
                throw new RuntimeException("비활성화된 계정입니다.");
            }

            // 계정 잠금 상태 확인 - 수정된 메서드명 사용
            if (user.isAccountLocked()) {
                throw new RuntimeException("계정이 잠겨있습니다. 잠시 후 다시 시도해주세요.");
            }

            // 비밀번호 확인
            if (!passwordEncoder.matches(request.getPassword(), user.getPassword())) {
                // 로그인 실패 시 시도 횟수 증가
                user.incrementLoginAttempts();
                userRepository.save(user);
                throw new RuntimeException("비밀번호가 일치하지 않습니다.");
            }

            // 로그인 성공 처리 - 수정된 메서드명 사용
            user.onLoginSuccess();
            user.setUpdatedAt(LocalDateTime.now());
            userRepository.save(user);

            // JWT 토큰 생성
            String token = jwtUtil.generateToken(user.getId(), user.getIsAdmin());

            logger.info("로그인 완료 - 사용자ID: {}", user.getId());
            return token;

        } catch (Exception e) {
            logger.error("로그인 처리 중 오류 발생", e);
            throw new RuntimeException("로그인에 실패했습니다: " + e.getMessage());
        }
    }

    /**
     * 사용자 정보 조회
     */
    @Transactional(readOnly = true)
    public UserResponse getUserById(String userId) {
        try {
            logger.info("사용자 정보 조회 - 사용자ID: {}", userId);

            User user = userRepository.findById(userId)
                    .orElseThrow(() -> new RuntimeException("사용자를 찾을 수 없습니다: " + userId));

            return convertToResponse(user);

        } catch (Exception e) {
            logger.error("사용자 정보 조회 중 오류 발생", e);
            throw new RuntimeException("사용자 정보 조회에 실패했습니다: " + e.getMessage());
        }
    }

// UserService.java의 updateUser 메서드를 아래 내용으로 교체하세요

    /**
     * 사용자 정보 수정
     */
    public UserResponse updateUser(String userId, UpdateUserRequest request) {
        try {
            logger.info("사용자 정보 수정 - 사용자ID: {}", userId);

            User user = userRepository.findById(userId)
                    .orElseThrow(() -> new RuntimeException("사용자를 찾을 수 없습니다: " + userId));

            // 정보 업데이트
            if (request.getName() != null && !request.getName().trim().isEmpty()) {
                user.setName(encryptionUtil.encrypt(request.getName()));
            }
            if (request.getEmail() != null && !request.getEmail().trim().isEmpty()) {
                user.setEmail(encryptionUtil.encrypt(request.getEmail()));
                user.setEmailHash(SecurityUtils.hashUserId(request.getEmail().trim()));
            }
            if (request.getPhoneNumber() != null && !request.getPhoneNumber().trim().isEmpty()) {
                user.setPhoneNumber(encryptionUtil.encrypt(request.getPhoneNumber()));
            }
            // ✅ 거주 동 업데이트 추가
            if (request.getDormitoryBuilding() != null && !request.getDormitoryBuilding().trim().isEmpty()) {
                user.setDormitoryBuilding(request.getDormitoryBuilding());
            }
            if (request.getRoomNumber() != null && !request.getRoomNumber().trim().isEmpty()) {
                user.setRoomNumber(request.getRoomNumber());
            }

            user.setUpdatedAt(LocalDateTime.now());
            user = userRepository.save(user);

            logger.info("사용자 정보 수정 완료 - 사용자ID: {}", userId);
            return convertToResponse(user);

        } catch (Exception e) {
            logger.error("사용자 정보 수정 중 오류 발생", e);
            throw new RuntimeException("사용자 정보 수정에 실패했습니다: " + e.getMessage());
        }
    }

    /**
     * 비밀번호 변경
     */
    public void changePassword(String userId, String currentPassword, String newPassword) {
        try {
            logger.info("비밀번호 변경 - 사용자ID: {}", userId);

            User user = userRepository.findById(userId)
                    .orElseThrow(() -> new RuntimeException("사용자를 찾을 수 없습니다: " + userId));

            // 현재 비밀번호 확인
            if (!passwordEncoder.matches(currentPassword, user.getPassword())) {
                throw new RuntimeException("현재 비밀번호가 일치하지 않습니다.");
            }

            // 새 비밀번호 설정
            user.setPassword(passwordEncoder.encode(newPassword));
            user.setPasswordChangedAt(LocalDateTime.now());
            user.setUpdatedAt(LocalDateTime.now());

            userRepository.save(user);
            logger.info("비밀번호 변경 완료 - 사용자ID: {}", userId);

        } catch (Exception e) {
            logger.error("비밀번호 변경 중 오류 발생", e);
            throw new RuntimeException("비밀번호 변경에 실패했습니다: " + e.getMessage());
        }
    }

    /**
     * 계정 잠금 해제 (관리자용)
     */
    public void unlockUserAccount(String userId) {
        try {
            logger.info("계정 잠금 해제 - 사용자ID: {}", userId);

            User user = userRepository.findById(userId)
                    .orElseThrow(() -> new RuntimeException("사용자를 찾을 수 없습니다: " + userId));

            user.setIsLocked(false);
            user.setLoginAttempts(0);
            user.setLockedUntil(null);
            user.setUpdatedAt(LocalDateTime.now());

            userRepository.save(user);
            logger.info("계정 잠금 해제 완료 - 사용자ID: {}", userId);

        } catch (Exception e) {
            logger.error("계정 잠금 해제 중 오류 발생", e);
            throw new RuntimeException("계정 잠금 해제에 실패했습니다: " + e.getMessage());
        }
    }

    /**
     * 사용자 비활성화 (관리자용)
     */
    public void deactivateUser(String userId) {
        try {
            logger.info("사용자 비활성화 - 사용자ID: {}", userId);

            User user = userRepository.findById(userId)
                    .orElseThrow(() -> new RuntimeException("사용자를 찾을 수 없습니다: " + userId));

            user.setIsActive(false);
            user.setUpdatedAt(LocalDateTime.now());

            userRepository.save(user);
            logger.info("사용자 비활성화 완료 - 사용자ID: {}", userId);

        } catch (Exception e) {
            logger.error("사용자 비활성화 중 오류 발생", e);
            throw new RuntimeException("사용자 비활성화에 실패했습니다: " + e.getMessage());
        }
    }

    /**
     * 모든 활성 사용자 조회 (관리자용)
     */
    @Transactional(readOnly = true)
    public List<UserResponse> getAllActiveUsers() {
        try {
            logger.info("모든 활성 사용자 조회");

            List<User> users = userRepository.findByIsActiveTrueOrderByCreatedAtDesc();
            return users.stream()
                    .map(this::convertToResponse)
                    .collect(Collectors.toList());

        } catch (Exception e) {
            logger.error("사용자 목록 조회 중 오류 발생", e);
            throw new RuntimeException("사용자 목록 조회에 실패했습니다: " + e.getMessage());
        }
    }

    /**
     * User 엔티티를 UserResponse DTO로 변환 - 알림 설정 제거
     */
    private UserResponse convertToResponse(User user) {
        try {
            UserResponse response = new UserResponse();
            response.setId(user.getId());
            response.setIsAdmin(user.getIsAdmin());
            response.setDormitoryBuilding(user.getDormitoryBuilding()); // ✅ 거주 동 추가
            response.setRoomNumber(user.getRoomNumber());
            response.setProfileImagePath(user.getProfileImagePath());
            response.setIsActive(user.getIsActive());
            response.setIsLocked(user.getIsLocked());
            response.setLastLoginAt(user.getLastLoginAt());
            response.setCreatedAt(user.getCreatedAt());
            response.setUpdatedAt(user.getUpdatedAt());
            response.setPasswordChangedAt(user.getPasswordChangedAt());
            response.setLoginAttempts(user.getLoginAttempts());

            // 암호화된 개인정보 복호화
            if (user.getName() != null) {
                response.setName(encryptionUtil.decrypt(user.getName()));
            }
            if (user.getEmail() != null) {
                response.setEmail(encryptionUtil.decrypt(user.getEmail()));
            }
            if (user.getPhoneNumber() != null) {
                response.setPhoneNumber(encryptionUtil.decrypt(user.getPhoneNumber()));
            }

            return response;

        } catch (Exception e) {
            logger.warn("사용자 정보 변환 중 일부 오류 발생 - 사용자ID: {}", user.getId());

            // 최소한의 정보라도 반환
            UserResponse response = new UserResponse();
            response.setId(user.getId());
            response.setIsAdmin(user.getIsAdmin());
            response.setDormitoryBuilding(user.getDormitoryBuilding()); // ✅ 거주 동 추가
            response.setRoomNumber(user.getRoomNumber());
            response.setIsActive(user.getIsActive());
            response.setCreatedAt(user.getCreatedAt());

            return response;
        }
    }
}