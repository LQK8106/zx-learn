package com.zhixing.user.controller;

import com.zhixing.common.annotation.RequireRole;
import com.zhixing.common.constants.UserRole;
import com.zhixing.common.domain.R;
import com.zhixing.user.domain.vo.UserVO;
import com.zhixing.user.service.UserService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * 教师管理。
 *
 * <p>教师账号**不开放自助注册**（2026-11-16 安全整改）：
 * 由管理员经 {@code POST /users} 创建并指定角色，避免匿名注册进入教师端。
 * 网关白名单也同步移除了 {@code /teachers/register}，本类不再提供该端点。
 */
@RestController
@RequestMapping("/teachers")
@RequiredArgsConstructor
public class TeacherController {

    private final UserService userService;

    /**
     * 教师分页查询（员工专用）。
     */
    @GetMapping("/page")
    @RequireRole(UserRole.STAFF)
    public R<List<UserVO>> page() {
        return R.ok(userService.pageQueryUsers(3));
    }
}
