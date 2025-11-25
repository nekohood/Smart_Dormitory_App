package com.dormitory.SpringBoot.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import com.fasterxml.jackson.datatype.jsr310.deser.LocalDateTimeDeserializer;
import com.fasterxml.jackson.datatype.jsr310.ser.LocalDateTimeSerializer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeFormatterBuilder;
import java.time.temporal.ChronoField;

/**
 * Jackson ObjectMapper 전역 설정
 * ISO 8601 형식의 날짜/시간 파싱 지원 (Z 포함, 밀리초 포함)
 */
@Configuration
public class JacksonConfig {

    /**
     * ISO 8601 형식을 지원하는 유연한 DateTimeFormatter
     * 지원 형식:
     * - 2025-11-25T03:46:15.478Z
     * - 2025-11-25T03:46:15Z
     * - 2025-11-25T03:46:15
     * - 2025-11-25 03:46:15
     */
    private static final DateTimeFormatter FLEXIBLE_DATE_TIME_FORMATTER = new DateTimeFormatterBuilder()
            .appendPattern("yyyy-MM-dd")
            .optionalStart()
            .appendLiteral('T')
            .optionalEnd()
            .optionalStart()
            .appendLiteral(' ')
            .optionalEnd()
            .appendPattern("HH:mm:ss")
            .optionalStart()
            .appendFraction(ChronoField.MILLI_OF_SECOND, 0, 3, true)
            .optionalEnd()
            .optionalStart()
            .appendLiteral('Z')
            .optionalEnd()
            .optionalStart()
            .appendOffset("+HH:MM", "Z")
            .optionalEnd()
            .toFormatter();

    @Bean
    @Primary
    public ObjectMapper objectMapper() {
        ObjectMapper objectMapper = new ObjectMapper();

        // Java 8 날짜/시간 모듈 등록
        JavaTimeModule javaTimeModule = new JavaTimeModule();

        // 커스텀 LocalDateTime Deserializer 등록
        javaTimeModule.addDeserializer(LocalDateTime.class, 
                new FlexibleLocalDateTimeDeserializer());

        // 기본 LocalDateTime Serializer 사용 (ISO 형식)
        javaTimeModule.addSerializer(LocalDateTime.class, 
                new LocalDateTimeSerializer(DateTimeFormatter.ISO_LOCAL_DATE_TIME));

        objectMapper.registerModule(javaTimeModule);

        // 날짜를 타임스탬프로 직렬화하지 않음
        objectMapper.disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);

        return objectMapper;
    }

    /**
     * 유연한 LocalDateTime Deserializer
     * 다양한 ISO 8601 형식 지원
     */
    private static class FlexibleLocalDateTimeDeserializer extends LocalDateTimeDeserializer {

        public FlexibleLocalDateTimeDeserializer() {
            super(DateTimeFormatter.ISO_DATE_TIME);
        }

        @Override
        protected LocalDateTime _fromString(com.fasterxml.jackson.core.JsonParser p, 
                                            com.fasterxml.jackson.databind.DeserializationContext ctxt,
                                            String string) throws java.io.IOException {
            try {
                // 'Z'로 끝나면 UTC로 파싱 후 LocalDateTime으로 변환
                if (string.endsWith("Z")) {
                    return java.time.ZonedDateTime.parse(string).toLocalDateTime();
                }
                // '+' 또는 타임존 오프셋이 있으면 ZonedDateTime으로 파싱
                if (string.contains("+") || string.matches(".*[+-]\\d{2}:\\d{2}$")) {
                    return java.time.ZonedDateTime.parse(string).toLocalDateTime();
                }
                // 'T' 구분자가 있으면 ISO_LOCAL_DATE_TIME으로 파싱
                if (string.contains("T")) {
                    return LocalDateTime.parse(string, DateTimeFormatter.ISO_LOCAL_DATE_TIME);
                }
                // 공백 구분자이면 커스텀 형식으로 파싱
                return LocalDateTime.parse(string, DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss"));
            } catch (Exception e) {
                // 모든 형식 실패 시 기본 파싱 시도
                return super._fromString(p, ctxt, string);
            }
        }
    }
}
