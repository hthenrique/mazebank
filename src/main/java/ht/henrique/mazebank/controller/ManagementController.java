package ht.henrique.mazebank.controller;

import ht.henrique.mazebank.exception.ControllerException;
import ht.henrique.mazebank.exception.DatabaseException;
import ht.henrique.mazebank.model.BaseResponse;
import ht.henrique.mazebank.model.create.CreateRequest;
import ht.henrique.mazebank.model.create.CreateResponse;
import ht.henrique.mazebank.model.deposit.DepositRequest;
import ht.henrique.mazebank.service.ManagementService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/management")
@Slf4j
public class ManagementController {

    @Autowired
    private ManagementService managementService;

    @PostMapping("/create")
    public ResponseEntity<BaseResponse> createUser(@RequestBody(required = false) CreateRequest createRequest) throws DatabaseException, ControllerException {
        if (createRequest == null){
            log.info("Invalid parameters");
            throw new ControllerException(HttpStatus.BAD_REQUEST, 400001, "Invalid parameters");
        }
        return ResponseEntity.status(HttpStatus.CREATED).body(managementService.createUser(createRequest));
    }

    @GetMapping("/fetch/user")
    public ResponseEntity<BaseResponse> getUser(@RequestHeader(value = "user-key",required = false) String userKey) throws ControllerException, DatabaseException {
        if (userKey == null || userKey.equals("")){
            log.info("Invalid parameters");
            throw new ControllerException(HttpStatus.BAD_REQUEST, 400001, "Invalid parameters");
        }
        return ResponseEntity.ok(managementService.getUser(userKey));
    }

    @PostMapping("/deposit/user")
    public ResponseEntity<BaseResponse> depositValue(@RequestBody(required = false) DepositRequest depositRequest,
            @RequestHeader(value = "user-uid", required = false) Long userId) throws ControllerException, DatabaseException {
        if (userId == null || userId.equals("")){
            log.info("Invalid parameters");
            throw new ControllerException(HttpStatus.BAD_REQUEST, 400001, "Invalid parameters");
        }

        if (depositRequest == null){
            log.info("Empty Request");
            throw new ControllerException(HttpStatus.BAD_REQUEST, 400001, "Empty Request");
        }

        return ResponseEntity.ok(managementService.depositValue(userId, depositRequest));
    }


}
