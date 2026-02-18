package mh.cyb.root.watch_employee.controller;

import mh.cyb.root.watch_employee.entity.*;
import mh.cyb.root.watch_employee.repository.*;
import mh.cyb.root.watch_employee.service.CredentialService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;
import org.springframework.beans.factory.annotation.Value;

import java.util.*;

@Controller
public class CredentialController {

    @Value("${app.activity.api-key}")
    private String expectedApiKey;

    private final CredentialService credentialService;
    private final EmployeeRepository employeeRepo;

    public CredentialController(CredentialService credentialService,
            EmployeeRepository employeeRepo) {
        this.credentialService = credentialService;
        this.employeeRepo = employeeRepo;
    }

    // ==================== ADMIN: Credentials ====================

    @GetMapping("/admin/credentials")
    public String credentialsPage(@RequestParam(required = false, defaultValue = "all") String filter,
            Model model) {
        List<Credential> credentials;
        switch (filter) {
            case "admin":
                credentials = credentialService.getAdminCredentials();
                break;
            case "user":
                credentials = credentialService.getUserSubmittedCredentials();
                break;
            default:
                credentials = credentialService.getAllCredentials();
        }
        model.addAttribute("credentials", credentials);
        model.addAttribute("groups", credentialService.getAllGroups());
        model.addAttribute("currentFilter", filter);
        return "credentials";
    }

    @PostMapping("/admin/credentials")
    public String addCredential(@RequestParam String siteName,
            @RequestParam String siteUrl,
            @RequestParam String username,
            @RequestParam String password,
            @RequestParam(required = false) String notes) {
        credentialService.saveCredential(siteName, siteUrl, username, password, notes);
        return "redirect:/admin/credentials";
    }

    @PostMapping("/admin/credentials/{id}/edit")
    public String editCredential(@PathVariable Long id,
            @RequestParam String siteName,
            @RequestParam String siteUrl,
            @RequestParam String username,
            @RequestParam(required = false) String password,
            @RequestParam(required = false) String notes) {
        credentialService.updateCredential(id, siteName, siteUrl, username, password, notes);
        return "redirect:/admin/credentials";
    }

    @PostMapping("/admin/credentials/{id}/delete")
    public String deleteCredential(@PathVariable Long id) {
        credentialService.deleteCredential(id);
        return "redirect:/admin/credentials";
    }

    // ==================== ADMIN: Groups ====================

    @GetMapping("/admin/credential-groups")
    public String groupsPage(Model model) {
        List<CredentialGroup> groups = credentialService.getAllGroups();
        List<Credential> allCredentials = credentialService.getAllCredentials();
        List<Employee> allEmployees = employeeRepo.findAll();

        // Build group details
        List<Map<String, Object>> groupDetails = new ArrayList<>();
        for (CredentialGroup group : groups) {
            Map<String, Object> detail = new LinkedHashMap<>();
            detail.put("group", group);
            detail.put("credentialCount", credentialService.getCredentialCountForGroup(group.getId()));
            detail.put("deviceCount", credentialService.getDeviceCountForGroup(group.getId()));
            detail.put("assignedCredentialIds", credentialService.getCredentialIdsByGroup(group.getId()));
            detail.put("assignedDeviceIds", credentialService.getDeviceIdsByGroup(group.getId()));
            groupDetails.add(detail);
        }

        model.addAttribute("groupDetails", groupDetails);
        model.addAttribute("allCredentials", allCredentials);
        model.addAttribute("allEmployees", allEmployees);
        return "credential_groups";
    }

    @PostMapping("/admin/credential-groups")
    public String createGroup(@RequestParam String name,
            @RequestParam(required = false) String description) {
        credentialService.saveGroup(name, description);
        return "redirect:/admin/credential-groups";
    }

    @PostMapping("/admin/credential-groups/{id}/edit")
    public String editGroup(@PathVariable Long id,
            @RequestParam String name,
            @RequestParam(required = false) String description) {
        credentialService.updateGroup(id, name, description);
        return "redirect:/admin/credential-groups";
    }

    @PostMapping("/admin/credential-groups/{id}/delete")
    public String deleteGroup(@PathVariable Long id) {
        credentialService.deleteGroup(id);
        return "redirect:/admin/credential-groups";
    }

    @PostMapping("/admin/credential-groups/{id}/assign")
    public String assignCredentials(@PathVariable Long id,
            @RequestParam(required = false) List<Long> credentialIds) {
        credentialService.assignCredentialsToGroup(id, credentialIds != null ? credentialIds : List.of());
        return "redirect:/admin/credential-groups";
    }

    @PostMapping("/admin/credential-groups/{id}/access")
    public String assignDevices(@PathVariable Long id,
            @RequestParam(required = false) List<String> deviceIds) {
        credentialService.assignDevicesToGroup(id, deviceIds != null ? deviceIds : List.of());
        return "redirect:/admin/credential-groups";
    }

    // ==================== API: Extension Endpoints ====================

    @GetMapping("/api/credentials")
    @ResponseBody
    public ResponseEntity<?> getCredentialsForDevice(
            @RequestHeader(value = "X-API-KEY", required = false) String apiKey,
            @RequestParam String deviceId) {

        if (expectedApiKey == null || expectedApiKey.isBlank() || !expectedApiKey.equals(apiKey)) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("Invalid API Key");
        }

        List<Map<String, Object>> credentials = credentialService.getCredentialsForDevice(deviceId);
        return ResponseEntity.ok(credentials);
    }

    @GetMapping("/api/credentials/{id}/copy")
    @ResponseBody
    public ResponseEntity<?> copyPassword(
            @RequestHeader(value = "X-API-KEY", required = false) String apiKey,
            @PathVariable Long id,
            @RequestParam String deviceId) {

        if (expectedApiKey == null || expectedApiKey.isBlank() || !expectedApiKey.equals(apiKey)) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("Invalid API Key");
        }

        try {
            String password = credentialService.copyPassword(id, deviceId);
            return ResponseEntity.ok(Map.of("password", password));
        } catch (SecurityException e) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body("Access denied");
        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body("Credential not found");
        }
    }

    // ==================== API: User-Saved Credentials ====================

    @PostMapping("/api/credentials")
    @ResponseBody
    public ResponseEntity<?> saveUserCredential(
            @RequestHeader(value = "X-API-KEY", required = false) String apiKey,
            @RequestBody Map<String, String> body) {

        if (expectedApiKey == null || expectedApiKey.isBlank() || !expectedApiKey.equals(apiKey)) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("Invalid API Key");
        }

        String deviceId = body.get("deviceId");
        String siteName = body.get("siteName");
        String siteUrl = body.get("siteUrl");
        String username = body.get("username");
        String password = body.get("password");
        String notes = body.get("notes");

        if (deviceId == null || siteName == null || siteUrl == null || username == null || password == null) {
            return ResponseEntity.badRequest().body("Missing required fields");
        }

        Credential cred = credentialService.saveUserCredential(deviceId, siteName, siteUrl, username, password, notes);
        return ResponseEntity.ok(Map.of(
                "id", cred.getId(),
                "siteName", cred.getSiteName(),
                "siteUrl", cred.getSiteUrl(),
                "username", cred.getUsername()));
    }

    @GetMapping("/api/credentials/my")
    @ResponseBody
    public ResponseEntity<?> getMyCredentials(
            @RequestHeader(value = "X-API-KEY", required = false) String apiKey,
            @RequestParam String deviceId) {

        if (expectedApiKey == null || expectedApiKey.isBlank() || !expectedApiKey.equals(apiKey)) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("Invalid API Key");
        }

        return ResponseEntity.ok(credentialService.getMyCredentials(deviceId));
    }

    @DeleteMapping("/api/credentials/{id}")
    @ResponseBody
    public ResponseEntity<?> deleteUserCredential(
            @RequestHeader(value = "X-API-KEY", required = false) String apiKey,
            @PathVariable Long id,
            @RequestParam String deviceId) {

        if (expectedApiKey == null || expectedApiKey.isBlank() || !expectedApiKey.equals(apiKey)) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("Invalid API Key");
        }

        boolean deleted = credentialService.deleteUserCredential(id, deviceId);
        if (deleted) {
            return ResponseEntity.ok(Map.of("status", "deleted"));
        } else {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body("Access denied or not found");
        }
    }
}
