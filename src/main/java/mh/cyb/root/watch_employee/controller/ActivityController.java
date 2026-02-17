package mh.cyb.root.watch_employee.controller;

import mh.cyb.root.watch_employee.entity.ActivityLog;
import mh.cyb.root.watch_employee.service.ActivityLogService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/activity")
public class ActivityController {

    private final ActivityLogService service;

    public ActivityController(ActivityLogService service) {
        this.service = service;
    }

    @PostMapping("/batch")
    public ResponseEntity<List<ActivityLog>> saveBatch(@RequestBody List<ActivityLog> logs,
            jakarta.servlet.http.HttpServletRequest request) {
        String clientIp = request.getRemoteAddr();
        logs.forEach(log -> {
            if (log.getDeviceId() == null || log.getDeviceId().trim().isEmpty()
                    || log.getDeviceId().equals("unknown")) {
                log.setDeviceId(clientIp);
            }
        });
        List<ActivityLog> savedLogs = service.saveBatch(logs);
        return ResponseEntity.ok(savedLogs);
    }

    @GetMapping("/health")
    public ResponseEntity<String> healthCheck() {
        return ResponseEntity.ok("Backend is running!");
    }
}
