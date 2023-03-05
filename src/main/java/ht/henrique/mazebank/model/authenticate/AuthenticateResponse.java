package ht.henrique.mazebank.model.authenticate;

import ht.henrique.mazebank.model.Response;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@AllArgsConstructor
@NoArgsConstructor
@Builder
public class AuthenticateResponse implements Response {

    private String message;

}
