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
import org.springframework.security.access.expression.method.DefaultMethodSecurityExpressionHandler;
import org.springframework.security.access.expression.method.MethodSecurityExpressionHandler;
import org.springframework.security.access.hierarchicalroles.RoleHierarchy;
import org.springframework.security.access.hierarchicalroles.RoleHierarchyImpl;

// CORS 관련 클래스 임포트
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;
import org.springframework.security.config.Customizer;
import org.springframework.http.HttpMethod;
import java.util.Arrays;

/**
 * Spring Security 설정
 * ✅ 수정: 비밀번호 변경 경로 명시적 허용 추가
 * ✅ 수정: 사용자 정보 관련 경로 USER/ADMIN 모두 허용
 */
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
     * ✅ 역할 계층 설정 - ADMIN은 USER의 모든 권한을 자동으로 포함
     * Spring Security 6.x 권장 방식 사용
     */
    @Bean
    public RoleHierarchy roleHierarchy() {
        // ROLE_ADMIN은 ROLE_USER의 모든 권한을 상속받음
        return RoleHierarchyImpl.fromHierarchy("ROLE_ADMIN > ROLE_USER");
    }

    /**
     * ✅ 메서드 보안 표현식 핸들러 - 역할 계층 적용
     */
    @Bean
    public MethodSecurityExpressionHandler methodSecurityExpressionHandler(RoleHierarchy roleHierarchy) {
        DefaultMethodSecurityExpressionHandler handler = new DefaultMethodSecurityExpressionHandler();
        handler.setRoleHierarchy(roleHierarchy);
        return handler;
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

                        // ✅ 학번 허용 여부 확인 (회원가입 시 사용 - 인증 불필요)
                        .requestMatchers("/api/allowed-users/check/**").permitAll()

                        // ✅ 허용 사용자 관리 - 관리자 전용 (GET/POST/PUT/DELETE 모두)
                        .requestMatchers(HttpMethod.GET, "/api/allowed-users/list").hasRole("ADMIN")
                        .requestMatchers(HttpMethod.GET, "/api/allowed-users/{userId}").hasRole("ADMIN")
                        .requestMatchers(HttpMethod.POST, "/api/allowed-users/**").hasRole("ADMIN")
                        .requestMatchers(HttpMethod.PUT, "/api/allowed-users/**").hasRole("ADMIN")
                        .requestMatchers(HttpMethod.DELETE, "/api/allowed-users/**").hasRole("ADMIN")

                        // ✅ [추가] 사용자 정보 관련 - 인증된 사용자 모두 허용 (USER, ADMIN)
                        .requestMatchers(HttpMethod.GET, "/api/users/me").hasAnyRole("USER", "ADMIN")
                        .requestMatchers(HttpMethod.PUT, "/api/users/me").hasAnyRole("USER", "ADMIN")
                        .requestMatchers(HttpMethod.PUT, "/api/users/me/password").hasAnyRole("USER", "ADMIN")

                        // ✅ 민원 제출 허용 (JWT 필터에서 인증 확인, 컨트롤러에서 권한 확인)
                        .requestMatchers("/api/complaints").permitAll()

                        // ✅ 서류 제출 허용 (JWT 필터에서 인증 확인, 컨트롤러에서 권한 확인)
                        .requestMatchers("/api/documents").permitAll()

                        // ✅ 관리자는 모든 API에 접근 가능
                        .requestMatchers("/api/**").hasAnyRole("ADMIN", "USER")

                        // 기타 모든 요청은 인증 필요
                        .anyRequest().authenticated()
                );

        return http.build();
    }
}