package com.dormitory.SpringBoot.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonProperty;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

/**
 * API 응답을 위한 표준 DTO 클래스
 * 모든 API 응답의 일관성을 보장합니다.
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
public class ApiResponse<T> {

    @JsonProperty("success")
    private boolean success;

    @JsonProperty("message")
    private String message;

    @JsonProperty("data")
    private T data;

    @JsonProperty("error")
    private ErrorDetails error;

    @JsonProperty("timestamp")
    private LocalDateTime timestamp;

    @JsonProperty("path")
    private String path;

    // 기본 생성자
    public ApiResponse() {
        this.timestamp = LocalDateTime.now();
    }

    // 성공 응답 생성자
    private ApiResponse(boolean success, String message, T data) {
        this();
        this.success = success;
        this.message = message;
        this.data = data;
    }

    // 오류 응답 생성자
    private ApiResponse(boolean success, String message, ErrorDetails error) {
        this();
        this.success = success;
        this.message = message;
        this.error = error;
    }

    // =============================================================================
    // 성공 응답 생성 메서드들
    // =============================================================================

    /**
     * 데이터와 함께 성공 응답 생성
     */
    public static <T> ApiResponse<T> success(T data) {
        return new ApiResponse<>(true, "성공", data);
    }

    /**
     * 메시지와 데이터와 함께 성공 응답 생성
     */
    public static <T> ApiResponse<T> success(String message, T data) {
        return new ApiResponse<>(true, message, data);
    }

    /**
     * 메시지만으로 성공 응답 생성
     */
    public static <T> ApiResponse<T> success(String message) {
        return new ApiResponse<>(true, message, null);
    }

    /**
     * 기본 성공 응답 생성
     */
    public static <T> ApiResponse<T> success() {
        return new ApiResponse<>(true, "성공", null);
    }

    // =============================================================================
    // 오류 응답 생성 메서드들
    // =============================================================================

    /**
     * 오류 메시지로 실패 응답 생성
     */
    public static <T> ApiResponse<T> error(String message) {
        ErrorDetails errorDetails = new ErrorDetails("GENERAL_ERROR", message);
        return new ApiResponse<>(false, message, errorDetails);
    }

    /**
     * 오류 코드와 메시지로 실패 응답 생성
     */
    public static <T> ApiResponse<T> error(String code, String message) {
        ErrorDetails errorDetails = new ErrorDetails(code, message);
        return new ApiResponse<>(false, message, errorDetails);
    }

    /**
     * 상세 오류 정보로 실패 응답 생성
     */
    public static <T> ApiResponse<T> error(String code, String message, Object details) {
        ErrorDetails errorDetails = new ErrorDetails(code, message, details);
        return new ApiResponse<>(false, message, errorDetails);
    }

    /**
     * 유효성 검증 오류 응답 생성
     */
    public static <T> ApiResponse<T> validationError(Map<String, String> fieldErrors) {
        ErrorDetails errorDetails = new ErrorDetails("VALIDATION_ERROR", "입력 값 검증에 실패했습니다.", fieldErrors);
        return new ApiResponse<>(false, "입력 값을 확인해주세요.", errorDetails);
    }

    /**
     * 인증 오류 응답 생성
     */
    public static <T> ApiResponse<T> unauthorized(String message) {
        ErrorDetails errorDetails = new ErrorDetails("UNAUTHORIZED", message != null ? message : "인증이 필요합니다.");
        return new ApiResponse<>(false, errorDetails.getMessage(), errorDetails);
    }

    /**
     * 권한 없음 오류 응답 생성
     */
    public static <T> ApiResponse<T> forbidden(String message) {
        ErrorDetails errorDetails = new ErrorDetails("FORBIDDEN", message != null ? message : "접근 권한이 없습니다.");
        return new ApiResponse<>(false, errorDetails.getMessage(), errorDetails);
    }

    /**
     * 찾을 수 없음 오류 응답 생성
     */
    public static <T> ApiResponse<T> notFound(String message) {
        ErrorDetails errorDetails = new ErrorDetails("NOT_FOUND", message != null ? message : "요청한 리소스를 찾을 수 없습니다.");
        return new ApiResponse<>(false, errorDetails.getMessage(), errorDetails);
    }

    /**
     * 서버 내부 오류 응답 생성
     */
    public static <T> ApiResponse<T> internalServerError(String message) {
        ErrorDetails errorDetails = new ErrorDetails("INTERNAL_SERVER_ERROR",
                message != null ? message : "서버 내부 오류가 발생했습니다.");
        return new ApiResponse<>(false, errorDetails.getMessage(), errorDetails);
    }

    // =============================================================================
    // 페이지네이션 응답 생성 메서드들
    // =============================================================================

    /**
     * 페이지네이션 데이터와 함께 성공 응답 생성
     */
    public static <T> ApiResponse<PagedData<T>> pagedSuccess(List<T> content,
                                                             int page,
                                                             int size,
                                                             long totalElements,
                                                             int totalPages) {
        PagedData<T> pagedData = new PagedData<>(content, page, size, totalElements, totalPages);
        return success("페이지 조회 성공", pagedData);
    }

    // =============================================================================
    // Getter/Setter
    // =============================================================================

    public boolean isSuccess() {
        return success;
    }

    public void setSuccess(boolean success) {
        this.success = success;
    }

    public String getMessage() {
        return message;
    }

    public void setMessage(String message) {
        this.message = message;
    }

    public T getData() {
        return data;
    }

    public void setData(T data) {
        this.data = data;
    }

    public ErrorDetails getError() {
        return error;
    }

    public void setError(ErrorDetails error) {
        this.error = error;
    }

    public LocalDateTime getTimestamp() {
        return timestamp;
    }

    public void setTimestamp(LocalDateTime timestamp) {
        this.timestamp = timestamp;
    }

    public String getPath() {
        return path;
    }

    public void setPath(String path) {
        this.path = path;
    }

    // =============================================================================
    // 내부 클래스들
    // =============================================================================

    /**
     * 오류 상세 정보를 담는 클래스
     */
    @JsonInclude(JsonInclude.Include.NON_NULL)
    public static class ErrorDetails {
        @JsonProperty("code")
        private String code;

        @JsonProperty("message")
        private String message;

        @JsonProperty("details")
        private Object details;

        public ErrorDetails() {}

        public ErrorDetails(String code, String message) {
            this.code = code;
            this.message = message;
        }

        public ErrorDetails(String code, String message, Object details) {
            this.code = code;
            this.message = message;
            this.details = details;
        }

        // Getter/Setter
        public String getCode() {
            return code;
        }

        public void setCode(String code) {
            this.code = code;
        }

        public String getMessage() {
            return message;
        }

        public void setMessage(String message) {
            this.message = message;
        }

        public Object getDetails() {
            return details;
        }

        public void setDetails(Object details) {
            this.details = details;
        }
    }

    /**
     * 페이지네이션 데이터를 담는 클래스
     */
    @JsonInclude(JsonInclude.Include.NON_NULL)
    public static class PagedData<T> {
        @JsonProperty("content")
        private List<T> content;

        @JsonProperty("page")
        private int page;

        @JsonProperty("size")
        private int size;

        @JsonProperty("totalElements")
        private long totalElements;

        @JsonProperty("totalPages")
        private int totalPages;

        @JsonProperty("first")
        private boolean first;

        @JsonProperty("last")
        private boolean last;

        @JsonProperty("hasNext")
        private boolean hasNext;

        @JsonProperty("hasPrevious")
        private boolean hasPrevious;

        public PagedData() {}

        public PagedData(List<T> content, int page, int size, long totalElements, int totalPages) {
            this.content = content;
            this.page = page;
            this.size = size;
            this.totalElements = totalElements;
            this.totalPages = totalPages;
            this.first = page == 0;
            this.last = page >= totalPages - 1;
            this.hasNext = page < totalPages - 1;
            this.hasPrevious = page > 0;
        }

        // Getter/Setter
        public List<T> getContent() {
            return content;
        }

        public void setContent(List<T> content) {
            this.content = content;
        }

        public int getPage() {
            return page;
        }

        public void setPage(int page) {
            this.page = page;
        }

        public int getSize() {
            return size;
        }

        public void setSize(int size) {
            this.size = size;
        }

        public long getTotalElements() {
            return totalElements;
        }

        public void setTotalElements(long totalElements) {
            this.totalElements = totalElements;
        }

        public int getTotalPages() {
            return totalPages;
        }

        public void setTotalPages(int totalPages) {
            this.totalPages = totalPages;
        }

        public boolean isFirst() {
            return first;
        }

        public void setFirst(boolean first) {
            this.first = first;
        }

        public boolean isLast() {
            return last;
        }

        public void setLast(boolean last) {
            this.last = last;
        }

        public boolean isHasNext() {
            return hasNext;
        }

        public void setHasNext(boolean hasNext) {
            this.hasNext = hasNext;
        }

        public boolean isHasPrevious() {
            return hasPrevious;
        }

        public void setHasPrevious(boolean hasPrevious) {
            this.hasPrevious = hasPrevious;
        }
    }
}