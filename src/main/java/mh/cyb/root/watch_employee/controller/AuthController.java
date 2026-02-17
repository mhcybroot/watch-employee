package mh.cyb.root.watch_employee.controller;

import mh.cyb.root.watch_employee.entity.AppUser;
import mh.cyb.root.watch_employee.service.AuthService;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

import java.security.Principal;
import java.util.List;

@Controller
public class AuthController {

    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    @GetMapping("/login")
    public String login() {
        return "login";
    }

    @GetMapping("/register")
    public String register() {
        return "register";
    }

    @PostMapping("/register")
    public String handleRegistration(
            @RequestParam String username,
            @RequestParam String password,
            @RequestParam String email,
            Model model) {
        try {
            authService.registerUser(username, password, email);
            return "redirect:/admin/users?registered";
        } catch (Exception e) {
            model.addAttribute("error", e.getMessage());
            return "register";
        }
    }

    // ===== Admin Management Endpoints =====

    @GetMapping("/admin/users")
    public String listAdmins(Model model, Principal principal) {
        List<AppUser> admins = authService.getAllAdmins();
        model.addAttribute("admins", admins);
        model.addAttribute("currentUsername", principal.getName());
        return "admin_users";
    }

    @GetMapping("/admin/users/{id}/edit")
    public String editAdminForm(@PathVariable Long id, Model model, Principal principal) {
        AppUser admin = authService.getAdminById(id);
        if (!admin.getUsername().equals(principal.getName())) {
            return "redirect:/admin/users?error=You+can+only+edit+your+own+account";
        }
        model.addAttribute("admin", admin);
        return "edit_admin";
    }

    @PostMapping("/admin/users/{id}/edit")
    public String handleEditAdmin(
            @PathVariable Long id,
            @RequestParam String username,
            @RequestParam String email,
            Principal principal,
            RedirectAttributes redirectAttributes) {
        try {
            AppUser target = authService.getAdminById(id);
            if (!target.getUsername().equals(principal.getName())) {
                throw new RuntimeException("You can only edit your own account.");
            }
            authService.updateAdmin(id, username, email);
            redirectAttributes.addFlashAttribute("success", "Profile updated successfully.");
        } catch (Exception e) {
            redirectAttributes.addFlashAttribute("error", e.getMessage());
        }
        return "redirect:/admin/users";
    }

    @PostMapping("/admin/users/{id}/change-password")
    public String handleChangePassword(
            @PathVariable Long id,
            @RequestParam String newPassword,
            Principal principal,
            RedirectAttributes redirectAttributes) {
        try {
            AppUser target = authService.getAdminById(id);
            if (!target.getUsername().equals(principal.getName())) {
                throw new RuntimeException("You can only change your own password.");
            }
            if (newPassword.length() < 6) {
                throw new RuntimeException("Password must be at least 6 characters.");
            }
            authService.changePassword(id, newPassword);
            redirectAttributes.addFlashAttribute("success", "Password changed successfully.");
        } catch (Exception e) {
            redirectAttributes.addFlashAttribute("error", e.getMessage());
        }
        return "redirect:/admin/users/" + id + "/edit";
    }

    @PostMapping("/admin/users/{id}/delete")
    public String handleDeleteAdmin(
            @PathVariable Long id,
            Principal principal,
            RedirectAttributes redirectAttributes) {
        try {
            AppUser target = authService.getAdminById(id);
            if (target.getUsername().equals(principal.getName())) {
                throw new RuntimeException("You cannot delete your own account.");
            }
            authService.deleteAdmin(id);
            redirectAttributes.addFlashAttribute("success", "Admin deleted successfully.");
        } catch (Exception e) {
            redirectAttributes.addFlashAttribute("error", e.getMessage());
        }
        return "redirect:/admin/users";
    }
}
