package ht.henrique.mazebank.service;

import ht.henrique.mazebank.exception.DatabaseException;
import ht.henrique.mazebank.model.BaseResponse;
import ht.henrique.mazebank.model.authenticate.AuthenticateRequest;
import org.springframework.http.ResponseEntity;

public interface AuthenticateService {

    ResponseEntity<BaseResponse> authenticate(AuthenticateRequest authenticateRequest) throws DatabaseException;
}
