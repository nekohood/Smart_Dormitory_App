package com.dormitory.SpringBoot.domain;

import com.fasterxml.jackson.annotation.JsonFormat;
import jakarta.persistence.*;
import lombok.*;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.LocalDateTime; // ✅ LocalDate 대신 LocalDateTime 사용

@Entity
@Getter
@Setter
@NoArgsConstructor
@EntityListeners(AuditingEntityListener.class) // ✅ CreatedDate, LastModifiedDate 활성화
public class Schedule {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String title; // (제목)

    // ❌ 기존 eventDate 필드 삭제
    // @Column(nullable = false)
    // private LocalDate eventDate; // 일정 날짜

    // ✅ 서비스 로직에 필요한 필드들 추가
    @Column(columnDefinition = "TEXT") // 내용은 길 수 있으므로 TEXT 타입 사용
    private String content; // (일정 내용)

    @Column(nullable = false)
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss") // JSON 직렬화/역직렬화 형식 지정
    private LocalDateTime startDate; // (일정 시작일)

    @Column(nullable = true) // 종료일은 선택 사항
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    private LocalDateTime endDate; // (일정 종료일)

    @Column(nullable = true)
    private String category; // (카테고리, 예: GENERAL, ACADEMIC)

    // ✅ (선택사항) 생성일, 수정일 자동 관리를 위한 필드
    @CreatedDate
    @Column(updatable = false, nullable = false)
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    private LocalDateTime createdAt;

    @LastModifiedDate
    @Column(nullable = false)
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    private LocalDateTime updatedAt;
}