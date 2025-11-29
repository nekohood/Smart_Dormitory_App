package com.dormitory.SpringBoot.services;

import com.dormitory.SpringBoot.domain.BuildingTableConfig;
import com.dormitory.SpringBoot.repository.BuildingTableConfigRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

/**
 * 기숙사 테이블 설정 서비스
 */
@Service
@Transactional
public class BuildingTableConfigService {

    private static final Logger logger = LoggerFactory.getLogger(BuildingTableConfigService.class);

    @Autowired
    private BuildingTableConfigRepository configRepository;

    /**
     * 모든 테이블 설정 조회
     */
    @Transactional(readOnly = true)
    public List<BuildingTableConfig> getAllConfigs() {
        logger.info("전체 테이블 설정 조회");
        return configRepository.findAllByOrderByBuildingNameAsc();
    }

    /**
     * 활성화된 테이블 설정만 조회
     */
    @Transactional(readOnly = true)
    public List<BuildingTableConfig> getActiveConfigs() {
        logger.info("활성화된 테이블 설정 조회");
        return configRepository.findByIsActiveTrueOrderByBuildingNameAsc();
    }

    /**
     * ID로 설정 조회
     */
    @Transactional(readOnly = true)
    public Optional<BuildingTableConfig> getConfigById(Long id) {
        return configRepository.findById(id);
    }

    /**
     * 기숙사 동 이름으로 설정 조회
     */
    @Transactional(readOnly = true)
    public Optional<BuildingTableConfig> getConfigByBuildingName(String buildingName) {
        return configRepository.findByBuildingNameAndIsActiveTrue(buildingName);
    }

    /**
     * 기숙사 동의 층/호실 범위 조회 (설정이 없으면 예시용 기본값 반환)
     */
    @Transactional(readOnly = true)
    public BuildingTableConfig getConfigOrDefault(String buildingName) {
        return configRepository.findByBuildingNameAndIsActiveTrue(buildingName)
                .orElseGet(() -> {
                    // ✅ 예시용 기본값 반환 (1~3층, 1~5호 - 작은 크기)
                    BuildingTableConfig defaultConfig = new BuildingTableConfig();
                    defaultConfig.setBuildingName("예시 템플릿");  // ✅ 실제 기숙사명이 아닌 "예시 템플릿"으로 표시
                    defaultConfig.setStartFloor(1);
                    defaultConfig.setEndFloor(3);
                    defaultConfig.setStartRoom(1);
                    defaultConfig.setEndRoom(5);
                    defaultConfig.setRoomNumberFormat("FLOOR_ROOM");
                    defaultConfig.setDescription("⚠️ 예시 테이블입니다. 설정 버튼을 눌러 실제 층/호실 범위를 설정해주세요.");
                    defaultConfig.setIsActive(false);  // 기본값임을 표시
                    return defaultConfig;
                });
    }

    /**
     * 기숙사 동의 설정이 존재하는지 확인
     */
    @Transactional(readOnly = true)
    public boolean hasConfig(String buildingName) {
        return configRepository.findByBuildingNameAndIsActiveTrue(buildingName).isPresent();
    }

    /**
     * 테이블 설정 생성
     */
    public BuildingTableConfig createConfig(String buildingName, Integer startFloor, Integer endFloor,
                                            Integer startRoom, Integer endRoom, String roomNumberFormat,
                                            String description, String adminId) {
        logger.info("테이블 설정 생성 - 동: {}", buildingName);

        // 중복 확인
        if (configRepository.existsByBuildingName(buildingName)) {
            throw new RuntimeException("이미 해당 기숙사의 설정이 존재합니다: " + buildingName);
        }

        // 유효성 검사
        validateConfig(startFloor, endFloor, startRoom, endRoom);

        BuildingTableConfig config = new BuildingTableConfig();
        config.setBuildingName(buildingName);
        config.setStartFloor(startFloor);
        config.setEndFloor(endFloor);
        config.setStartRoom(startRoom);
        config.setEndRoom(endRoom);
        config.setRoomNumberFormat(roomNumberFormat != null ? roomNumberFormat : "FLOOR_ROOM");
        config.setDescription(description);
        config.setIsActive(true);
        config.setCreatedBy(adminId);

        BuildingTableConfig saved = configRepository.save(config);
        logger.info("테이블 설정 생성 완료 - ID: {}, 동: {}", saved.getId(), buildingName);

        return saved;
    }

    /**
     * 테이블 설정 수정
     */
    public BuildingTableConfig updateConfig(Long id, String buildingName, Integer startFloor, Integer endFloor,
                                            Integer startRoom, Integer endRoom, String roomNumberFormat,
                                            String description, String adminId) {
        logger.info("테이블 설정 수정 - ID: {}", id);

        BuildingTableConfig config = configRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("설정을 찾을 수 없습니다: " + id));

        // 동 이름 변경 시 중복 확인
        if (buildingName != null && !buildingName.equals(config.getBuildingName())) {
            if (configRepository.existsByBuildingNameAndIdNot(buildingName, id)) {
                throw new RuntimeException("이미 해당 기숙사의 설정이 존재합니다: " + buildingName);
            }
            config.setBuildingName(buildingName);
        }

        // 유효성 검사
        int newStartFloor = startFloor != null ? startFloor : config.getStartFloor();
        int newEndFloor = endFloor != null ? endFloor : config.getEndFloor();
        int newStartRoom = startRoom != null ? startRoom : config.getStartRoom();
        int newEndRoom = endRoom != null ? endRoom : config.getEndRoom();
        validateConfig(newStartFloor, newEndFloor, newStartRoom, newEndRoom);

        if (startFloor != null) config.setStartFloor(startFloor);
        if (endFloor != null) config.setEndFloor(endFloor);
        if (startRoom != null) config.setStartRoom(startRoom);
        if (endRoom != null) config.setEndRoom(endRoom);
        if (roomNumberFormat != null) config.setRoomNumberFormat(roomNumberFormat);
        if (description != null) config.setDescription(description);
        config.setUpdatedBy(adminId);

        BuildingTableConfig saved = configRepository.save(config);
        logger.info("테이블 설정 수정 완료 - ID: {}", id);

        return saved;
    }

    /**
     * 테이블 설정 삭제
     */
    public void deleteConfig(Long id) {
        logger.info("테이블 설정 삭제 - ID: {}", id);

        BuildingTableConfig config = configRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("설정을 찾을 수 없습니다: " + id));

        configRepository.delete(config);
        logger.info("테이블 설정 삭제 완료 - ID: {}, 동: {}", id, config.getBuildingName());
    }

    /**
     * 테이블 설정 활성화/비활성화 토글
     */
    public BuildingTableConfig toggleActive(Long id) {
        logger.info("테이블 설정 토글 - ID: {}", id);

        BuildingTableConfig config = configRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("설정을 찾을 수 없습니다: " + id));

        config.setIsActive(!config.getIsActive());
        BuildingTableConfig saved = configRepository.save(config);

        logger.info("테이블 설정 토글 완료 - ID: {}, 활성화: {}", id, saved.getIsActive());
        return saved;
    }

    /**
     * 층/호실 목록 생성
     */
    public List<Integer> getFloorList(String buildingName) {
        BuildingTableConfig config = getConfigOrDefault(buildingName);
        List<Integer> floors = new ArrayList<>();
        for (int i = config.getStartFloor(); i <= config.getEndFloor(); i++) {
            floors.add(i);
        }
        return floors;
    }

    public List<Integer> getRoomList(String buildingName) {
        BuildingTableConfig config = getConfigOrDefault(buildingName);
        List<Integer> rooms = new ArrayList<>();
        for (int i = config.getStartRoom(); i <= config.getEndRoom(); i++) {
            rooms.add(i);
        }
        return rooms;
    }

    /**
     * 유효성 검사
     */
    private void validateConfig(int startFloor, int endFloor, int startRoom, int endRoom) {
        if (startFloor < 1 || startFloor > 100) {
            throw new RuntimeException("시작 층수는 1~100 사이여야 합니다.");
        }
        if (endFloor < 1 || endFloor > 100) {
            throw new RuntimeException("종료 층수는 1~100 사이여야 합니다.");
        }
        if (startFloor > endFloor) {
            throw new RuntimeException("시작 층수는 종료 층수보다 작거나 같아야 합니다.");
        }
        if (startRoom < 1 || startRoom > 100) {
            throw new RuntimeException("시작 호실은 1~100 사이여야 합니다.");
        }
        if (endRoom < 1 || endRoom > 100) {
            throw new RuntimeException("종료 호실은 1~100 사이여야 합니다.");
        }
        if (startRoom > endRoom) {
            throw new RuntimeException("시작 호실은 종료 호실보다 작거나 같아야 합니다.");
        }

        // 테이블 크기 제한 (최대 50x50 = 2500칸)
        int totalCells = (endFloor - startFloor + 1) * (endRoom - startRoom + 1);
        if (totalCells > 2500) {
            throw new RuntimeException("테이블 크기가 너무 큽니다. 최대 2500칸까지 가능합니다. (현재: " + totalCells + "칸)");
        }
    }
}