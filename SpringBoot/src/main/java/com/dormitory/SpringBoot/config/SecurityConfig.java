package com.dormitory.SpringBoot.config;

import com.dormitory.SpringBoot.filter.JwtAuthenticationFilter;
// import com.dormitory.SpringBoot.utils.JwtUtil; // ❗️ 이 줄은 더 이상 필요 없습니다.
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
import org.springframework.security.config.Customizer; // Customizer 임포트
import java.util.Arrays;

@Configuration
@EnableWebSecurity
@EnableMethodSecurity(prePostEnabled = true) // @PreAuthorize 활성화
public class SecurityConfig {

    // ✅ 1. JwtUtil 대신 Spring이 관리하는 JwtAuthenticationFilter Bean을 직접 주입받습니다.
    private final JwtAuthenticationFilter jwtAuthenticationFilter;

    // ✅ 2. 생성자 수정: JwtAuthenticationFilter를 주입받도록 변경합니다.
    public SecurityConfig(JwtAuthenticationFilter jwtAuthenticationFilter) {
        this.jwtAuthenticationFilter = jwtAuthenticationFilter;
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    /**
     * 전역 CORS 설정을 정의합니다.
     * 플러터 웹 (Chrome)에서 발생하는 CORS 오류를 해결하기 위해 필요합니다.
     */
    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration configuration = new CorsConfiguration();

        // 🌟 모든 출처에서의 요청을 허용합니다. (개발 환경)
        configuration.setAllowedOrigins(Arrays.asList("*"));

        // 🌟 모든 HTTP 메서드(GET, POST, PUT, DELETE, OPTIONS 등)를 허용합니다.
        configuration.setAllowedMethods(Arrays.asList("GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"));

        // 🌟 모든 헤더 (Authorization 포함)를 허용합니다.
        configuration.setAllowedHeaders(Arrays.asList("*"));

        // 🌟 자격 증명(쿠키 등)을 허용할지 여부 (JWT 토큰만 사용 시 false도 무방)
        configuration.setAllowCredentials(false);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        // 모든 경로("/**")에 대해 위 CORS 설정을 적용합니다.
        source.registerCorsConfiguration("/**", configuration);

        return source;
    }

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
                // 1. CORS 설정 적용 (가장 중요)
                // 위에서 정의한 corsConfigurationSource() Bean을 사용하도록 설정합니다.
                .cors(Customizer.withDefaults())

                // 2. CSRF 비활성화 (Stateless JWT 사용)
                .csrf(AbstractHttpConfigurer::disable)

                // 3. 세션 정책 설정 (Stateless)
                // 세션을 사용하지 않으므로 STATELESS로 설정합니다.
                .sessionManagement(session -> session
                        .sessionCreationPolicy(SessionCreationPolicy.STATELESS)
                )

                // ✅ 4. JWT 필터 추가 (수정된 부분)
                // 'new'로 생성하는 대신, Spring으로부터 주입받은 Bean을 사용합니다.
                .addFilterBefore(jwtAuthenticationFilter,
                        UsernamePasswordAuthenticationFilter.class)

                // 5. 경로별 접근 권한 설정
                .authorizeHttpRequests(authorize -> authorize
                        // /api/auth/** 경로는 인증 없이 모두 허용 (로그인, 회원가입)
                        .requestMatchers("/api/auth/**").permitAll()

                        // /hello, /actuator/health 등 공개 엔드포인트 허용
                        .requestMatchers("/hello", "/actuator/health").permitAll()

                        // Swagger UI 경로 허용 (필터에서 이미 스킵하고 있지만, 명시적으로 추가)
                        .requestMatchers("/swagger-ui/**", "/v3/api-docs/**", "/swagger-ui.html").permitAll()

                        // 파일 업로드 경로 허용 (필터에서 이미 스킵하고 있지만, 명시적으로 추가)
                        .requestMatchers("/uploads/**").permitAll()

                        // 기타 모든 요청은 인증(로그인)이 필요합니다.
                        .anyRequest().authenticated()
                );

        return http.build();
    }
}