package com.dormitory.SpringBoot.config;

import com.dormitory.SpringBoot.filter.JwtAuthenticationFilter;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.annotation.web.configurers.HeadersConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.Arrays;
import java.util.List;

/**
 * Spring Security 설정 클래스 - 캘린더 및 D-Day 기능 추가
 */
@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Autowired
    private JwtAuthenticationFilter jwtAuthenticationFilter;

    /**
     * 비밀번호 인코더 빈 등록
     */
    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    /**
     * CORS 설정 - 웹 개발 환경을 위한 최종 설정
     */
    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration configuration = new CorsConfiguration();

        // setAllowedOrigins 대신 setAllowedOriginPatterns를 사용하여 패턴으로 허용
        // 이렇게 하면 localhost와 127.0.0.1의 모든 포트를 허용할 수 있습니다.
        configuration.setAllowedOriginPatterns(Arrays.asList(
                "http://localhost:*",
                "http://127.0.0.1:*",
                "http://10.0.2.2:*"  // Android 에뮬레이터용
        ));

        // 허용할 HTTP 메서드 설정
        configuration.setAllowedMethods(Arrays.asList(
                "GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"
        ));

        // 허용할 헤더 설정
        configuration.setAllowedHeaders(Arrays.asList("*"));

        // 자격 증명 허용
        configuration.setAllowCredentials(true);

        // preflight 요청의 캐시 시간
        configuration.setMaxAge(3600L);

        // 노출할 헤더 설정
        configuration.setExposedHeaders(Arrays.asList(
                "Authorization",
                "Content-Type",
                "X-Requested-With",
                "Accept",
                "Origin",
                "Access-Control-Request-Method",
                "Access-Control-Request-Headers"
        ));

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", configuration);

        return source;
    }

    /**
     * 보안 필터 체인 설정
     */
    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
                // CORS 설정 활성화
                .cors(cors -> cors.configurationSource(corsConfigurationSource()))

                // CSRF 비활성화 (JWT 사용하므로)
                .csrf(AbstractHttpConfigurer::disable)

                // 기본 폼 로그인 비활성화
                .formLogin(AbstractHttpConfigurer::disable)

                // HTTP Basic 인증 비활성화
                .httpBasic(AbstractHttpConfigurer::disable)

                // 세션 관리 설정 (JWT 사용하므로 STATELESS)
                .sessionManagement(session ->
                        session.sessionCreationPolicy(SessionCreationPolicy.STATELESS)
                )

                // 헤더 설정
                .headers(headers ->
                        headers.frameOptions(HeadersConfigurer.FrameOptionsConfig::deny)
                )

                // 요청별 권한 설정
                .authorizeHttpRequests(auth -> auth
                        // OPTIONS 요청은 모든 경로에서 허용
                        .requestMatchers(HttpMethod.OPTIONS, "/**").permitAll()

                        // 인증이 필요없는 공개 엔드포인트
                        .requestMatchers("/hello/**").permitAll()
                        .requestMatchers("/api/auth/**").permitAll()
                        .requestMatchers("/actuator/health").permitAll()
                        .requestMatchers("/swagger-ui/**").permitAll()
                        .requestMatchers("/v3/api-docs/**").permitAll()
                        .requestMatchers("/swagger-ui.html").permitAll()
                        .requestMatchers("/uploads/**").permitAll() // 업로드된 파일 접근

                        // 관리자만 접근 가능한 엔드포인트
                        .requestMatchers("/api/admin/**").hasRole("ADMIN")
                        .requestMatchers("/api/inspections/admin/**").hasRole("ADMIN")
                        .requestMatchers("/api/notices/admin/**").hasRole("ADMIN")

                        // 점호 관련 엔드포인트 - 인증된 사용자 모두 접근 가능
                        .requestMatchers(HttpMethod.GET, "/api/inspections/**").authenticated()
                        .requestMatchers(HttpMethod.POST, "/api/inspections/**").authenticated()

                        // 민원 관련 엔드포인트 - 인증된 사용자 모두 접근 가능
                        .requestMatchers(HttpMethod.GET, "/api/complaints/**").authenticated()
                        .requestMatchers(HttpMethod.POST, "/api/complaints").authenticated()
                        .requestMatchers(HttpMethod.PUT, "/api/complaints/*/status").hasRole("ADMIN") // 상태 변경은 관리자만
                        .requestMatchers(HttpMethod.DELETE, "/api/complaints/*").hasRole("ADMIN") // 삭제는 관리자만

                        // 서류 관련 엔드포인트 - 인증된 사용자 모두 접근 가능
                        .requestMatchers(HttpMethod.GET, "/api/documents/**").authenticated()
                        .requestMatchers(HttpMethod.POST, "/api/documents").authenticated()
                        .requestMatchers(HttpMethod.POST, "/api/documents/submit-json").authenticated() // JSON 엔드포인트 추가
                        .requestMatchers(HttpMethod.PUT, "/api/documents/*/status").hasRole("ADMIN") // 상태 변경은 관리자만
                        .requestMatchers(HttpMethod.DELETE, "/api/documents/*").hasRole("ADMIN") // 삭제는 관리자만

                        // 공지사항 관련 엔드포인트 - 조회는 모두, 작성/수정/삭제는 관리자만
                        .requestMatchers(HttpMethod.GET, "/api/notices/**").authenticated()
                        .requestMatchers(HttpMethod.POST, "/api/notices").hasRole("ADMIN")
                        .requestMatchers(HttpMethod.PUT, "/api/notices/**").hasRole("ADMIN")
                        .requestMatchers(HttpMethod.DELETE, "/api/notices/**").hasRole("ADMIN")

                        // 캘린더 관련 엔드포인트
                        .requestMatchers(HttpMethod.GET, "/api/calendar/**").authenticated()
                        .requestMatchers(HttpMethod.POST, "/api/calendar").hasRole("ADMIN")
                        .requestMatchers(HttpMethod.PUT, "/api/calendar/**").hasRole("ADMIN")
                        .requestMatchers(HttpMethod.DELETE, "/api/calendar/**").hasRole("ADMIN")

                        // D-Day 관련 엔드포인트
                        .requestMatchers(HttpMethod.GET, "/api/dday/**").authenticated()
                        .requestMatchers(HttpMethod.POST, "/api/dday").hasRole("ADMIN")
                        .requestMatchers(HttpMethod.PUT, "/api/dday/**").hasRole("ADMIN")
                        .requestMatchers(HttpMethod.DELETE, "/api/dday/**").hasRole("ADMIN")

                        // 그 외 모든 요청은 인증 필요
                        .anyRequest().authenticated()
                )

                // JWT 인증 필터 추가
                .addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }
}
