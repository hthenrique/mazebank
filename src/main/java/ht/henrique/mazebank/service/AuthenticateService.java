package ht.henrique.mazebank.service;

import ht.henrique.mazebank.model.authenticate.AuthenticateRequest;
import ht.henrique.mazebank.model.authenticate.AuthenticateResponse;
import org.springframework.http.ResponseEntity;

public interface AuthenticateService {

    ResponseEntity<AuthenticateResponse> authenticate(AuthenticateRequest authenticateRequest);
}
