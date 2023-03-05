package ht.henrique.mazebank.model.mapper;


import ht.henrique.mazebank.model.create.CreateRequest;
import ht.henrique.mazebank.model.database.User;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.Mappings;

@Mapper(componentModel = "spring")
public interface UserMapper {

    @Mappings({
            @Mapping(source = "create.username", target = "user_name"),
            @Mapping(source = "create.useremail", target = "user_account_key"),
            @Mapping(source = "create.userpass", target = "user_pass")
    })
    User createToUser(CreateRequest create);

}
