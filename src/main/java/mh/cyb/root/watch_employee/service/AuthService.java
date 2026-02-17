package mh.cyb.root.watch_employee.service;

import mh.cyb.root.watch_employee.entity.AppUser;
import mh.cyb.root.watch_employee.repository.UserRepository;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    public AuthService(UserRepository userRepository, PasswordEncoder passwordEncoder) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
    }

    public void registerUser(String username, String password, String email) {
        if (userRepository.existsByUsername(username)) {
            throw new RuntimeException("Username already exists");
        }
        if (userRepository.existsByEmail(email)) {
            throw new RuntimeException("Email already exists");
        }

        AppUser user = new AppUser();
        user.setUsername(username);
        user.setPassword(passwordEncoder.encode(password));
        user.setEmail(email);
        user.setRole("ROLE_ADMIN");

        userRepository.save(user);
    }

    public List<AppUser> getAllAdmins() {
        return userRepository.findAll();
    }

    public AppUser getAdminById(Long id) {
        return userRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Admin not found with ID: " + id));
    }

    public void updateAdmin(Long id, String username, String email) {
        AppUser user = getAdminById(id);

        // Check uniqueness only if the value changed
        if (!user.getUsername().equals(username) && userRepository.existsByUsername(username)) {
            throw new RuntimeException("Username already exists");
        }
        if (!user.getEmail().equals(email) && userRepository.existsByEmail(email)) {
            throw new RuntimeException("Email already exists");
        }

        user.setUsername(username);
        user.setEmail(email);
        userRepository.save(user);
    }

    public void changePassword(Long id, String newPassword) {
        AppUser user = getAdminById(id);
        user.setPassword(passwordEncoder.encode(newPassword));
        userRepository.save(user);
    }

    public void deleteAdmin(Long id) {
        if (!userRepository.existsById(id)) {
            throw new RuntimeException("Admin not found with ID: " + id);
        }
        userRepository.deleteById(id);
    }
}
