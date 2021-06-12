server source code of the pictionary website [https://www.udig.online](https://www.udig.online)

|ready|choose word|draw|
|:---:|:---:|:---:|
|![ready](https://user-images.githubusercontent.com/6159178/119751236-5cd57c00-becd-11eb-8741-4e2257bf3f47.png)|![choose word](https://user-images.githubusercontent.com/6159178/119752151-08cb9700-becf-11eb-9106-765477615152.png)|![draw](https://user-images.githubusercontent.com/6159178/119752191-1f71ee00-becf-11eb-992c-fb392b54cb95.png)|

# setup
(1) create directories
```bash
mkdir -p public/artworks public/avatars
```

(2) copy a font file to public directory, make sure public/avatar_font.ttf file exist

(3) update credentials if needed
```bash
bin/rails credentials:edit
```

(4) edit db/seeds.rb file then run
```bash
bin/rails db:setup
```

(5) run locally then setup frontend project, see [https://github.com/fzdp/draw-guess-frontend](https://github.com/fzdp/draw-guess-frontend)
