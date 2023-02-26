package ht.henrique.mazebank.service.impl;

import ht.henrique.mazebank.model.authenticate.AuthenticateRequest;
import ht.henrique.mazebank.model.authenticate.AuthenticateResponse;
import ht.henrique.mazebank.model.database.User;
import ht.henrique.mazebank.model.reposiory.UserRepository;
import ht.henrique.mazebank.service.AuthenticateService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class AuthenticationServiceImpl implements AuthenticateService {

    @Autowired
    private UserRepository userRepository;

    @Override
    public ResponseEntity<AuthenticateResponse> authenticate(AuthenticateRequest authenticateRequest) {
        List<User> listUser = null;
        User user = null;

        try {
            listUser = userRepository.findByUserAccountKey(authenticateRequest.getUsername());

            if (listUser.size() == 1){
                user = listUser.get(0);
            }

            if (user == null){
                return ResponseEntity.status(HttpStatus.NOT_FOUND).body(new AuthenticateResponse("User not found"));
            }

        }catch (Exception e){
            System.out.println(e.getMessage());
        }


        if (authenticateRequest.getUsername() == null && authenticateRequest.getUserpass() == null){
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(new AuthenticateResponse("Invalid Parameters"));
        }else {
            if (!authenticateRequest.getUserpass().equals(user.getUser_pass())){
                return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(new AuthenticateResponse("fail"));
            }
        }
        return ResponseEntity.status(HttpStatus.OK).body(new AuthenticateResponse("Success"));
    }

}
