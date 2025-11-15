package com.dormitory.SpringBoot.services;

import com.dormitory.SpringBoot.domain.DDay;
import com.dormitory.SpringBoot.dto.DDayDTO;
import com.dormitory.SpringBoot.repository.DDayRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;
import java.util.stream.Collectors;

/**
 * D-Day 서비스
 */
@Service
public class DDayService {

    @Autowired
    private DDayRepository ddayRepository;

    /**
     * 모든 활성화된 D-Day 조회
     */
    public List<DDayDTO> getAllActiveDDays() {
        return ddayRepository.findByIsActiveTrueOrderByTargetDateAsc()
                .stream()
                .map(DDayDTO::new)
                .collect(Collectors.toList());
    }

    /**
     * 모든 D-Day 조회 (비활성화 포함)
     */
    public List<DDayDTO> getAllDDays() {
        return ddayRepository.findAllByOrderByTargetDateAsc()
                .stream()
                .map(DDayDTO::new)
                .collect(Collectors.toList());
    }

    /**
     * ID로 D-Day 조회
     */
    public DDayDTO getDDayById(Long id) {
        DDay dday = ddayRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("D-Day를 찾을 수 없습니다. ID: " + id));
        return new DDayDTO(dday);
    }

    /**
     * 중요 D-Day 조회
     */
    public List<DDayDTO> getImportantDDays() {
        return ddayRepository.findByIsImportantTrueAndIsActiveTrueOrderByTargetDateAsc()
                .stream()
                .map(DDayDTO::new)
                .collect(Collectors.toList());
    }

    /**
     * 다가오는 D-Day 조회 (N일 이내)
     */
    public List<DDayDTO> getUpcomingDDays(int days) {
        LocalDate futureDate = LocalDate.now().plusDays(days);
        return ddayRepository.findUpcomingDDays(futureDate)
                .stream()
                .map(DDayDTO::new)
                .collect(Collectors.toList());
    }

    /**
     * 오늘 도래하는 D-Day 조회
     */
    public List<DDayDTO> getTodayDDays() {
        return ddayRepository.findTodayDDays()
                .stream()
                .map(DDayDTO::new)
                .collect(Collectors.toList());
    }

    /**
     * 제목으로 D-Day 검색
     */
    public List<DDayDTO> searchDDaysByTitle(String title) {
        return ddayRepository.findByTitleContainingIgnoreCaseOrderByTargetDateAsc(title)
                .stream()
                .map(DDayDTO::new)
                .collect(Collectors.toList());
    }

    /**
     * D-Day 생성 (관리자 전용)
     */
    @Transactional
    public DDayDTO createDDay(DDayDTO ddayDTO, String createdBy) {
        DDay dday = ddayDTO.toEntity();
        dday.setCreatedBy(createdBy);
        
        DDay savedDDay = ddayRepository.save(dday);
        return new DDayDTO(savedDDay);
    }

    /**
     * D-Day 수정 (관리자 전용)
     */
    @Transactional
    public DDayDTO updateDDay(Long id, DDayDTO ddayDTO) {
        DDay existingDDay = ddayRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("D-Day를 찾을 수 없습니다. ID: " + id));

        // 수정 가능한 필드 업데이트
        existingDDay.setTitle(ddayDTO.getTitle());
        existingDDay.setDescription(ddayDTO.getDescription());
        existingDDay.setTargetDate(ddayDTO.getTargetDate());
        existingDDay.setColor(ddayDTO.getColor());
        existingDDay.setIsActive(ddayDTO.getIsActive());
        existingDDay.setIsImportant(ddayDTO.getIsImportant());

        DDay updatedDDay = ddayRepository.save(existingDDay);
        return new DDayDTO(updatedDDay);
    }

    /**
     * D-Day 삭제 (관리자 전용)
     */
    @Transactional
    public void deleteDDay(Long id) {
        if (!ddayRepository.existsById(id)) {
            throw new RuntimeException("D-Day를 찾을 수 없습니다. ID: " + id);
        }
        ddayRepository.deleteById(id);
    }

    /**
     * D-Day 활성화/비활성화 (관리자 전용)
     */
    @Transactional
    public DDayDTO toggleDDayActive(Long id) {
        DDay dday = ddayRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("D-Day를 찾을 수 없습니다. ID: " + id));
        
        dday.setIsActive(!dday.getIsActive());
        DDay updatedDDay = ddayRepository.save(dday);
        return new DDayDTO(updatedDDay);
    }

    /**
     * 생성자별 D-Day 조회 (관리자용)
     */
    public List<DDayDTO> getDDaysByCreator(String createdBy) {
        return ddayRepository.findByCreatedByOrderByTargetDateDesc(createdBy)
                .stream()
                .map(DDayDTO::new)
                .collect(Collectors.toList());
    }

    /**
     * 활성화된 D-Day 개수
     */
    public long getActiveDDayCount() {
        return ddayRepository.countByIsActiveTrue();
    }

    /**
     * 중요 D-Day 개수
     */
    public long getImportantDDayCount() {
        return ddayRepository.countByIsImportantTrueAndIsActiveTrue();
    }
}
