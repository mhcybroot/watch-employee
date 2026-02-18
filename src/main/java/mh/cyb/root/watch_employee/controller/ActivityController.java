package mh.cyb.root.watch_employee.controller;

import mh.cyb.root.watch_employee.entity.ActivityLog;
import mh.cyb.root.watch_employee.service.ActivityLogService;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import jakarta.servlet.http.HttpServletRequest;
import java.util.List;

@RestController
@RequestMapping("/api/activity")
public class ActivityController {

    @Value("${app.activity.api-key}")
    private String expectedApiKey;

    private final ActivityLogService service;

    public ActivityController(ActivityLogService service) {
        this.service = service;
    }

    @PostMapping("/batch")
    public ResponseEntity<?> saveBatch(
            @RequestHeader(value = "X-API-KEY", required = false) String apiKey,
            @RequestBody List<ActivityLog> logs,
            HttpServletRequest request) {

        System.out.println("Received batch request from IP: " + request.getRemoteAddr() + ", Logs count: "
                + (logs != null ? logs.size() : "null"));

        // Fix #8: Require API key even if property is somehow null
        if (expectedApiKey == null || expectedApiKey.isBlank() || !expectedApiKey.equals(apiKey)) {
            // Fix #9: Don't log the expected key in cleartext
            System.err.println("Invalid API Key received from: " + request.getRemoteAddr());
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("Invalid API Key");
        }

        String clientIp = request.getRemoteAddr();

        for (ActivityLog log : logs) {
            if (log.getDeviceId() == null || log.getDeviceId().trim().isEmpty()
                    || log.getDeviceId().equals("unknown")) {
                log.setDeviceId(clientIp);
            }
        }

        List<ActivityLog> savedLogs = service.saveBatch(logs);
        System.out.println("Successfully saved " + savedLogs.size() + " logs.");
        return ResponseEntity.ok(savedLogs);
    }

    @GetMapping("/health")
    public ResponseEntity<String> healthCheck() {
        return ResponseEntity.ok("Backend is running!");
    }
}
