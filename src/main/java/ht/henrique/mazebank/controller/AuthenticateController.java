package ht.henrique.mazebank.controller;

import ht.henrique.mazebank.exception.ControllerException;
import ht.henrique.mazebank.exception.DatabaseException;
import ht.henrique.mazebank.model.BaseResponse;
import ht.henrique.mazebank.model.authenticate.AuthenticateRequest;
import ht.henrique.mazebank.model.authenticate.AuthenticateResponse;
import ht.henrique.mazebank.service.AuthenticateService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/authenticate")
@Slf4j
public class AuthenticateController {

    @Autowired
    private AuthenticateService authenticateService;

    @PostMapping("/user")
    public ResponseEntity<BaseResponse> authenticateUser(
            @RequestBody(required = false) AuthenticateRequest authenticateRequest
    ) throws ControllerException, DatabaseException {

        if (authenticateRequest == null || authenticateRequest.getUsername() == null || authenticateRequest.getUserpass() == null){
            log.info("Invalid parameters");
            throw new ControllerException(HttpStatus.BAD_REQUEST, 400001, "Invalid parameters");
        }
        return authenticateService.authenticate(authenticateRequest);
    }
}
