package mh.cyb.root.watch_employee.controller;

import mh.cyb.root.watch_employee.entity.ActivityLog;
import mh.cyb.root.watch_employee.repository.ActivityLogRepository;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;

import java.util.List;

@Controller
public class AdminController {

    private final ActivityLogRepository repository;
    private final mh.cyb.root.watch_employee.repository.EmployeeRepository employeeRepository;

    public AdminController(ActivityLogRepository repository,
            mh.cyb.root.watch_employee.repository.EmployeeRepository employeeRepository) {
        this.repository = repository;
        this.employeeRepository = employeeRepository;
    }

    @GetMapping("/admin")
    public String adminDashboard(Model model) {
        // 1. Logs Table
        List<ActivityLog> logs = repository.findAll(Sort.by(Sort.Direction.DESC, "startTime"));
        model.addAttribute("logs", logs);

        // 2. Employee Map
        java.util.Map<String, String> employeeMap = employeeRepository.findAll().stream()
                .collect(java.util.stream.Collectors.toMap(mh.cyb.root.watch_employee.entity.Employee::getDeviceId,
                        mh.cyb.root.watch_employee.entity.Employee::getName));
        model.addAttribute("employeeMap", employeeMap);

        // 3. Summary Metrics
        long totalDuration = repository.getTotalDurationSeconds();
        long totalEmployees = employeeRepository.count();
        long activeToday = repository.countActiveDevicesSince(java.time.LocalDate.now().atStartOfDay());

        model.addAttribute("totalDuration", formatDuration(totalDuration));
        model.addAttribute("totalEmployees", totalEmployees);
        model.addAttribute("activeToday", activeToday);

        // 4. Charts Data
        model.addAttribute("chartActivityByHour", repository.getActivityByHour());
        model.addAttribute("chartTopDomains", repository.getTopDomains());

        return "admin";
    }

    private String formatDuration(long seconds) {
        long hours = seconds / 3600;
        long minutes = (seconds % 3600) / 60;
        return String.format("%dh %dm", hours, minutes);
    }

    @GetMapping("/admin/devices")
    public String devices(Model model) {
        // Get unique device IDs from logs
        List<String> deviceIds = repository.findDistinctDeviceIds();
        // Get existing employees
        List<mh.cyb.root.watch_employee.entity.Employee> employees = employeeRepository.findAll();

        // Create a merged list/DTO for the view
        List<mh.cyb.root.watch_employee.entity.Employee> viewList = new java.util.ArrayList<>();

        for (String id : deviceIds) {
            mh.cyb.root.watch_employee.entity.Employee emp = employees.stream()
                    .filter(e -> e.getDeviceId().equals(id))
                    .findFirst()
                    .orElse(new mh.cyb.root.watch_employee.entity.Employee(id, null, null));
            viewList.add(emp);
        }

        model.addAttribute("devices", viewList);
        return "devices";
    }

    @org.springframework.web.bind.annotation.PostMapping("/admin/employees")
    public String saveEmployee(
            @org.springframework.web.bind.annotation.ModelAttribute mh.cyb.root.watch_employee.entity.Employee employee) {
        employeeRepository.save(employee);
        return "redirect:/admin/devices";
    }

    @GetMapping("/admin/activity/{deviceId}")
    public String employeeActivity(
            @org.springframework.web.bind.annotation.PathVariable String deviceId,
            @org.springframework.web.bind.annotation.RequestParam(required = false) String startDate,
            @org.springframework.web.bind.annotation.RequestParam(required = false) String endDate,
            @org.springframework.web.bind.annotation.RequestParam(required = false) String domain,
            Model model) {

        // Parse filter dates
        java.time.LocalDateTime startDateTime = null;
        java.time.LocalDateTime endDateTime = null;
        String filterDomain = (domain != null && !domain.isBlank()) ? domain : null;

        if (startDate != null && !startDate.isBlank()) {
            startDateTime = java.time.LocalDate.parse(startDate).atStartOfDay();
        }
        if (endDate != null && !endDate.isBlank()) {
            endDateTime = java.time.LocalDate.parse(endDate).atTime(23, 59, 59);
        }

        // Employee info
        mh.cyb.root.watch_employee.entity.Employee employee = employeeRepository.findById(deviceId)
                .orElse(new mh.cyb.root.watch_employee.entity.Employee(deviceId, "Unknown Device", null));
        model.addAttribute("employee", employee);

        // Filtered logs
        List<ActivityLog> logs = repository.findByDeviceIdFiltered(deviceId, startDateTime, endDateTime, filterDomain);
        model.addAttribute("logs", logs);

        // Summary metrics
        long totalDuration = repository.getTotalDurationByDeviceIdFiltered(deviceId, startDateTime, endDateTime,
                filterDomain);
        long logCount = repository.countByDeviceIdFiltered(deviceId, startDateTime, endDateTime, filterDomain);
        model.addAttribute("totalDuration", formatDuration(totalDuration));
        model.addAttribute("logCount", logCount);

        // Domain breakdown (for sidebar)
        java.util.List<java.util.Map<String, Object>> domainStats = repository
                .getDomainStatsByDeviceIdFiltered(deviceId, startDateTime, endDateTime);
        java.util.List<java.util.Map<String, Object>> formattedStats = new java.util.ArrayList<>();

        long maxDuration = 1; // Avoid divide by zero
        for (java.util.Map<String, Object> stat : domainStats) {
            long duration = (long) stat.get("totalDuration");
            if (duration > maxDuration)
                maxDuration = duration;
        }

        for (java.util.Map<String, Object> stat : domainStats) {
            java.util.Map<String, Object> entry = new java.util.HashMap<>(stat);
            long duration = (long) stat.get("totalDuration");
            entry.put("formattedDuration", formatDuration(duration));
            entry.put("percentage", (duration * 100) / maxDuration);
            formattedStats.add(entry);
        }
        model.addAttribute("domainStats", formattedStats);

        // Domain list for dropdown
        java.util.List<String> domains = repository.findDistinctDomainsByDeviceId(deviceId);
        model.addAttribute("domains", domains);

        // Find top domain
        String topDomain = "-";
        if (!domainStats.isEmpty()) {
            topDomain = (String) domainStats.get(0).get("domain");
        }
        model.addAttribute("topDomain", topDomain);

        // Pass current filter values back to repopulate form
        model.addAttribute("filterStartDate", startDate != null ? startDate : "");
        model.addAttribute("filterEndDate", endDate != null ? endDate : "");
        model.addAttribute("filterDomain", domain != null ? domain : "");

        return "employee_activity";
    }
}
