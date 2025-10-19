package com.dormitory.SpringBoot.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.data.jpa.repository.config.EnableJpaAuditing;
import org.springframework.data.jpa.repository.config.EnableJpaRepositories;

@Configuration
@EnableJpaRepositories(basePackages = "com.dormitory.SpringBoot.repository") // "dormitory" -> "dormitory" 수정
@EnableJpaAuditing
public class JpaConfig {
    // JPA 관련 설정이 필요하면 여기에 추가
}