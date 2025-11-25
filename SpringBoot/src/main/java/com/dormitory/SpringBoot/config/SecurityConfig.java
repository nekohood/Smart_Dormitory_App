package com.dormitory.SpringBoot.config;

import com.dormitory.SpringBoot.filter.JwtAuthenticationFilter;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

// CORS 관련 클래스 임포트
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;
import org.springframework.security.config.Customizer;
import java.util.Arrays;

@Configuration
@EnableWebSecurity
@EnableMethodSecurity(prePostEnabled = true)
public class SecurityConfig {

    private final JwtAuthenticationFilter jwtAuthenticationFilter;

    public SecurityConfig(JwtAuthenticationFilter jwtAuthenticationFilter) {
        this.jwtAuthenticationFilter = jwtAuthenticationFilter;
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    /**
     * 전역 CORS 설정
     */
    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration configuration = new CorsConfiguration();

        // 모든 출처 허용 (개발 환경)
        configuration.setAllowedOrigins(Arrays.asList("*"));

        // 모든 HTTP 메서드 허용
        configuration.setAllowedMethods(Arrays.asList("GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"));

        // 모든 헤더 허용
        configuration.setAllowedHeaders(Arrays.asList("*"));

        // 자격 증명 허용 (JWT 토큰 사용 시 false도 가능)
        configuration.setAllowCredentials(false);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", configuration);

        return source;
    }

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
                // 1. CORS 설정 적용
                .cors(Customizer.withDefaults())

                // 2. CSRF 비활성화 (Stateless JWT 사용)
                .csrf(AbstractHttpConfigurer::disable)

                // 3. 세션 정책 설정 (Stateless)
                .sessionManagement(session -> session
                        .sessionCreationPolicy(SessionCreationPolicy.STATELESS)
                )

                // 4. JWT 필터 추가
                .addFilterBefore(jwtAuthenticationFilter,
                        UsernamePasswordAuthenticationFilter.class)

                // 5. 경로별 접근 권한 설정
                .authorizeHttpRequests(authorize -> authorize
                        // ✅ 인증 없이 허용되는 경로들
                        .requestMatchers("/api/auth/**").permitAll()  // 로그인, 회원가입, 토큰 검증
                        .requestMatchers("/hello", "/actuator/health").permitAll()  // 헬스체크
                        .requestMatchers("/swagger-ui/**", "/v3/api-docs/**", "/swagger-ui.html").permitAll()  // Swagger
                        .requestMatchers("/uploads/**").permitAll()  // 파일 업로드

                        // ✅ 민원 제출 허용 (JWT 필터에서 인증 확인, 컨트롤러에서 권한 확인)
                        .requestMatchers("/api/complaints").permitAll()

                        // ✅ 서류 제출 허용 (JWT 필터에서 인증 확인, 컨트롤러에서 권한 확인)
                        .requestMatchers("/api/documents").permitAll()

                        // 기타 모든 요청은 인증 필요
                        .anyRequest().authenticated()
                );

        return http.build();
    }
}