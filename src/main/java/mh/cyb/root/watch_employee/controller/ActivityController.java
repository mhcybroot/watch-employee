package mh.cyb.root.watch_employee.controller;

import mh.cyb.root.watch_employee.entity.ActivityLog;
import mh.cyb.root.watch_employee.service.ActivityLogService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/activity")
public class ActivityController {
    
    @org.springframework.beans.factory.annotation.Value("${app.activity.api-key}")
    private String expectedApiKey;

    private final ActivityLogService service;

    public ActivityController(ActivityLogService service) {
        this.service = service;
    }

    @PostMapping("/batch")
    public ResponseEntity<?> saveBatch(
            @RequestHeader(value = "X-API-KEY", required = false) String apiKey,
            @RequestBody List<@jakarta.validation.Valid ActivityLog> logs,
            jakarta.servlet.http.HttpServletRequest request) {
        
        if (expectedApiKey != null && !expectedApiKey.equals(apiKey)) {
            return ResponseEntity.status(org.springframework.http.HttpStatus.UNAUTHORIZED).body("Invalid API Key");
        }

        String clientIp = request.getRemoteAddr();

        for (ActivityLog log : logs) {
            if (log.getDeviceId() == null || log.getDeviceId().trim().isEmpty()
                    || log.getDeviceId().equals("unknown")) {
                log.setDeviceId(clientIp);
            }
        }

        List<ActivityLog> savedLogs = service.saveBatch(logs);
        return ResponseEntity.ok(savedLogs);
    }

    @GetMapping("/health")
    public ResponseEntity<String> healthCheck() {
        return ResponseEntity.ok("Backend is running!");
    }
}
