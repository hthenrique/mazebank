package ht.henrique.mazebank.controller;

import ht.henrique.mazebank.model.authenticate.AuthenticateRequest;
import ht.henrique.mazebank.model.authenticate.AuthenticateResponse;
import ht.henrique.mazebank.service.AuthenticateService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/authenticate")
public class AuthenticateController {

    @Autowired
    private AuthenticateService authenticateService;

    @PostMapping("/user")
    public ResponseEntity<AuthenticateResponse> authenticateUser(
            @RequestBody(required = false) AuthenticateRequest authenticateRequest
            ){
        return authenticateService.authenticate(authenticateRequest);
    }
}
