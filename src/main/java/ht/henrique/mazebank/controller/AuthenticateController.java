package ht.henrique.mazebank.controller;

import ht.henrique.mazebank.exception.ControllerException;
import ht.henrique.mazebank.exception.DatabaseException;
import ht.henrique.mazebank.exception.UtilsException;
import ht.henrique.mazebank.model.BaseResponse;
import ht.henrique.mazebank.model.authenticate.AuthenticateRequest;
import ht.henrique.mazebank.model.type.ReturnCode;
import ht.henrique.mazebank.service.AuthenticateService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/authenticate")
@Slf4j
@CrossOrigin(origins = "*", methods = { RequestMethod.GET, RequestMethod.POST, RequestMethod.PUT, RequestMethod.DELETE })
public class AuthenticateController {

    @Autowired
    private AuthenticateService authenticateService;

    @PostMapping("/user")
    public ResponseEntity<BaseResponse> authenticateUser(
            @RequestBody(required = false) AuthenticateRequest authenticateRequest
    ) throws ControllerException, DatabaseException, UtilsException {

        if (authenticateRequest == null || authenticateRequest.getUsername() == null || authenticateRequest.getUserpass() == null){
            log.info("Invalid parameters");
            throw new ControllerException(ReturnCode.INVALID_PARAMETERS, "Invalid parameters");
        }
        return ResponseEntity.ok(authenticateService.authenticate(authenticateRequest));
    }
}
